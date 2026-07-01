import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

/// Parameters for the off-thread image pipeline.
class _ImageJob {
  final Uint8List bytes;
  final int maxDim;
  final int quality;
  const _ImageJob(this.bytes, this.maxDim, this.quality);
}

/// Runs in a background isolate (via `compute`): downscale to [maxDim] on the
/// longest side, apply EXIF orientation, strip ALL EXIF/GPS, and re-encode as a
/// compressed JPEG. Falls back to the original bytes if decoding fails. Pure
/// Dart (`image` package) so it's isolate-safe and never touches the UI thread.
Uint8List _processImage(_ImageJob job) {
  try {
    final decoded = img.decodeImage(job.bytes);
    if (decoded == null) return job.bytes;
    var image = img.bakeOrientation(decoded); // honor orientation, drop EXIF
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > job.maxDim) {
      image = image.width >= image.height
          ? img.copyResize(image, width: job.maxDim)
          : img.copyResize(image, height: job.maxDim);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: job.quality));
  } catch (_) {
    return job.bytes;
  }
}

/// Handles all Firebase Storage uploads.
///
/// Every image is processed before upload (off the UI thread): **resized** to a
/// sensible cap, **compressed** (JPEG), and **stripped of EXIF/GPS** — cutting
/// storage + download-bandwidth cost, speeding loads, and protecting location
/// privacy. Chat images are stored under the chat scope (participants-only) with
/// unguessable names; a server `scanImage` function additionally screens uploads.
///
/// Paths:
///   - profile_photos/{uid}.jpg                  (avatar; ≤512px)
///   - post_images/{uid}/{ts}_{rand}.jpg         (feed; ≤1440px)
///   - chat_images/{chatScopeId}/{ts}_{rand}.jpg (participants-only; ≤1440px)
///   - gyms/{gymId}/logo.jpg                      (logo; ≤512px)
class StorageUploadService {
  static final StorageUploadService _instance =
      StorageUploadService._internal();
  factory StorageUploadService() => _instance;
  StorageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Tuning. Photos render at ≤1440px; avatars/logos are shown small (≤512px).
  static const int _maxPhotoDim = 1440;
  static const int _maxAvatarDim = 512;
  static const int _jpegQuality = 82;

  String _randomId() => _uuid.v4().replaceAll('-', '');

  /// Upload a profile photo. Returns the public download URL.
  Future<String> uploadProfilePhoto({
    required String userId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child('profile_photos/$userId.jpg');
    return _upload(ref, imageFile, onProgress, maxDim: _maxAvatarDim);
  }

  /// Upload a community post image. Returns the public download URL.
  Future<String> uploadPostImage({
    required String userId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref =
        _storage.ref().child('post_images/$userId/${ts}_${_randomId()}.jpg');
    return _upload(ref, imageFile, onProgress);
  }

  /// Upload a chat image message. Returns the download URL.
  ///
  /// [chatScopeId] scopes the object to the conversation: for a 1:1 chat pass
  /// the sorted participant pair joined by `_` (e.g. `uidA_uidB`) so the storage
  /// rule can enforce participants-only access; for group chats pass the chatId.
  Future<String> uploadChatImage({
    required String chatScopeId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('chat_images/$chatScopeId/${ts}_${_randomId()}.jpg');
    return _upload(ref, imageFile, onProgress);
  }

  Future<String> _upload(
    Reference ref,
    File file,
    void Function(double)? onProgress, {
    int maxDim = _maxPhotoDim,
  }) async {
    final raw = await file.readAsBytes();
    // Resize + compress + EXIF-strip in a background isolate (no UI jank).
    Uint8List clean;
    try {
      clean = await compute(_processImage, _ImageJob(raw, maxDim, _jpegQuality));
    } catch (e) {
      debugPrint('StorageUploadService: image processing failed: $e');
      clean = raw;
    }

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = ref.putData(clean, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        final progress = snap.bytesTransferred /
            (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        onProgress(progress);
      });
    }

    final snapshot = await task;
    final url = await snapshot.ref.getDownloadURL();
    // Do NOT log the tokenized URL (grants unauthenticated read). Log path+size.
    debugPrint('StorageUploadService: uploaded ${ref.fullPath} '
        '(${(raw.length / 1024).round()}KB → ${(clean.length / 1024).round()}KB)');
    return url;
  }

  /// Upload a gym logo. Returns the public download URL.
  Future<String> uploadGymLogo({
    required String gymId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child('gyms/$gymId/logo.jpg');
    return _upload(ref, imageFile, onProgress, maxDim: _maxAvatarDim);
  }

  /// Uploads a gym registration document (PDF or image) to Firebase Storage.
  /// Documents are uploaded as-is (may be PDFs) — not image-processed.
  Future<String> uploadGymDocument({
    required String uid,
    required String fileName,
    required File file,
  }) async {
    final ref = _storage.ref('gym_applications/$uid/documents/$fileName');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    debugPrint('StorageUploadService: gym document uploaded ${ref.fullPath}');
    return url;
  }

  /// Uploads a coach registration document (PDF or image) to Firebase Storage.
  Future<String> uploadCoachDocument({
    required String uid,
    required String fileName,
    required File file,
  }) async {
    final ref = _storage.ref('coach_applications/$uid/documents/$fileName');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    debugPrint('StorageUploadService: coach document uploaded ${ref.fullPath}');
    return url;
  }

  /// Delete a file by its download URL.
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('StorageUploadService.deleteByUrl error: $e');
    }
  }
}
