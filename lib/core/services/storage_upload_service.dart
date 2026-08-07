import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

/// Parameters for the off-thread image pipeline. [thumbMaxDim]/[thumbQuality]
/// are null for a plain single-size job (avatar/post/gym-logo uploads —
/// [_processImage] then skips thumbnail generation entirely).
class _ImageJob {
  final Uint8List bytes;
  final int maxDim;
  final int quality;
  final int? thumbMaxDim;
  final int? thumbQuality;
  const _ImageJob(
    this.bytes,
    this.maxDim,
    this.quality, {
    this.thumbMaxDim,
    this.thumbQuality,
  });
}

/// Result of [_processImage] — the full-size (always present) processed
/// image, plus an optional thumbnail. [width]/[height] are the FULL image's
/// final (post-resize) pixel dimensions — i.e. exactly what [full] actually
/// contains, not the pre-resize original's.
class _ProcessedImage {
  final Uint8List full;
  final Uint8List? thumb;
  final int? width;
  final int? height;
  const _ProcessedImage(
      {required this.full, this.thumb, this.width, this.height});
}

/// Runs in a background isolate (via `compute`): downscale to [_ImageJob
/// .maxDim] on the longest side, apply EXIF orientation, strip ALL EXIF/GPS,
/// and re-encode as a compressed JPEG. Falls back to the original bytes if
/// decoding fails. Pure Dart (`image` package) so it's isolate-safe and never
/// touches the UI thread.
///
/// Faz 5 (Piece C) — when [_ImageJob.thumbMaxDim] is set, ALSO derives a
/// small thumbnail from the SAME already-decoded (and orientation-baked)
/// image — never a second `img.decodeImage` pass over the original bytes —
/// so both sizes cost exactly one decode.
_ProcessedImage _processImage(_ImageJob job) {
  try {
    final decoded = img.decodeImage(job.bytes);
    if (decoded == null) return _ProcessedImage(full: job.bytes);
    final baked = img.bakeOrientation(decoded); // honor orientation, drop EXIF

    img.Image resizeToMax(int maxDim) {
      final longest = baked.width > baked.height ? baked.width : baked.height;
      if (longest <= maxDim) return baked;
      return baked.width >= baked.height
          ? img.copyResize(baked, width: maxDim)
          : img.copyResize(baked, height: maxDim);
    }

    final fullImage = resizeToMax(job.maxDim);
    final fullBytes =
        Uint8List.fromList(img.encodeJpg(fullImage, quality: job.quality));

    Uint8List? thumbBytes;
    final thumbMaxDim = job.thumbMaxDim;
    if (thumbMaxDim != null) {
      final thumbImage = resizeToMax(thumbMaxDim);
      thumbBytes = Uint8List.fromList(
          img.encodeJpg(thumbImage, quality: job.thumbQuality ?? 70));
    }

    return _ProcessedImage(
      full: fullBytes,
      thumb: thumbBytes,
      width: fullImage.width,
      height: fullImage.height,
    );
  } catch (_) {
    return _ProcessedImage(full: job.bytes);
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
///   - chat_media/{chatId}/{uid}/{ts}_{rand}.jpg (Faz 5 — group-chat scoping
///     fix; write-only client-side, read ONLY via the `getChatMediaUrl`
///     callable — see [uploadGroupChatMedia])
///   - chat_audio/{chatScopeId}/{ts}_{rand}.m4a  (Faz 6 — voice messages;
///     participants-only, mirrors chat_images' scoping — see
///     [uploadChatVoice])
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

  // Faz 5 (Piece C) — chat-image thumbnail tuning. ≤320px longest side,
  // quality 70 (a bit more aggressive than the full image's 82 — a thumbnail
  // is never viewed at full size, so a smaller file matters more than
  // fidelity here).
  static const int _maxThumbDim = 320;
  static const int _thumbJpegQuality = 70;

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

  /// Upload a chat image message. Returns the full-size download URL, the
  /// thumbnail's download URL (≤320px, generated from the SAME decode pass
  /// as the full image — see [_processImage]), and the full image's final
  /// pixel dimensions.
  ///
  /// [chatScopeId] scopes the object to the conversation: for a 1:1 chat pass
  /// the sorted participant pair joined by `_` (e.g. `uidA_uidB`) so the storage
  /// rule can enforce participants-only access; for group chats pass the chatId.
  ///
  /// Faz 5 (Piece D) — this is the LEGACY/current path, kept exactly as-is:
  /// for a group chat, `chatScopeId` has no `_`, so `storage.rules`' access
  /// check there degrades to "any authenticated user can read" (documented
  /// gap — Storage rules can't call Firestore to verify real group
  /// membership). This is NOT migrated here; see [uploadGroupChatMedia] for
  /// the new, properly-scoped path new call sites should adopt.
  Future<({String url, String? thumbUrl, int? width, int? height})>
      uploadChatImage({
    required String chatScopeId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final baseName = '${ts}_${_randomId()}';
    final ref = _storage.ref().child('chat_images/$chatScopeId/$baseName.jpg');
    final thumbRef =
        _storage.ref().child('chat_images/$chatScopeId/${baseName}_thumb.jpg');
    return _uploadWithThumb(ref, thumbRef, imageFile, onProgress);
  }

  /// Faz 5 (Piece D) — group-chat image upload via the SCOPED
  /// `chat_media/{chatId}/{uid}/{fileName}` path (`storage.rules`: write-only
  /// for the uploading owner, `allow read: if false` ALWAYS — see that
  /// block's comment). Returns bare STORAGE PATHS, not download URLs: there
  /// is no download URL to mint client-side for a `read: false` path.
  /// Resolving a path into a real, time-limited URL happens later, at render
  /// time, via `ChatMediaUrlCache` + the `getChatMediaUrl` callable
  /// (`functions/chat_media.js`), which re-verifies the caller is a real
  /// chat participant/group-member server-side before minting a signed URL.
  ///
  /// This is ADDITIVE, not a migration — [uploadChatImage] above is
  /// unchanged and still the path every existing call site uses; only a NEW
  /// call site choosing to fix the group-chat scoping gap should call this
  /// instead. See the `MessageAttachment.storagePath`/`thumbStoragePath`
  /// doc comment for how a caller wires the result into a sent message.
  Future<({String path, String? thumbPath, int? width, int? height})>
      uploadGroupChatMedia({
    required String chatId,
    required String uid,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final baseName = '${ts}_${_randomId()}';
    final path = 'chat_media/$chatId/$uid/$baseName.jpg';
    final thumbPath = 'chat_media/$chatId/$uid/${baseName}_thumb.jpg';
    final ref = _storage.ref().child(path);
    final thumbRef = _storage.ref().child(thumbPath);

    final raw = await imageFile.readAsBytes();
    final processed = await _processForUpload(raw);

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = ref.putData(processed.full, metadata);
    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        final progress = snap.bytesTransferred /
            (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        onProgress(progress);
      });
    }
    await task; // No getDownloadURL() — `read: false`; nothing to resolve here.

    String? uploadedThumbPath;
    if (processed.thumb != null) {
      try {
        await thumbRef.putData(processed.thumb!, metadata);
        uploadedThumbPath = thumbPath;
      } catch (e) {
        debugPrint(
            'StorageUploadService: group-media thumbnail upload failed: $e');
      }
    }

    debugPrint('StorageUploadService: uploaded $path (group-scoped, '
        '${(raw.length / 1024).round()}KB → ${(processed.full.length / 1024).round()}KB, '
        'read via getChatMediaUrl callable)');

    return (
      path: path,
      thumbPath: uploadedThumbPath,
      width: processed.width,
      height: processed.height,
    );
  }

  /// Off-thread resize/compress/EXIF-strip + thumbnail generation shared by
  /// [_uploadWithThumb] and [uploadGroupChatMedia] — one isolate call, one
  /// decode, both output sizes.
  Future<_ProcessedImage> _processForUpload(Uint8List raw) async {
    try {
      return await compute(
        _processImage,
        _ImageJob(
          raw,
          _maxPhotoDim,
          _jpegQuality,
          thumbMaxDim: _maxThumbDim,
          thumbQuality: _thumbJpegQuality,
        ),
      );
    } catch (e) {
      debugPrint('StorageUploadService: image processing failed: $e');
      return _ProcessedImage(full: raw);
    }
  }

  Future<({String url, String? thumbUrl, int? width, int? height})>
      _uploadWithThumb(
    Reference ref,
    Reference thumbRef,
    File file,
    void Function(double)? onProgress,
  ) async {
    final raw = await file.readAsBytes();
    final processed = await _processForUpload(raw);

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = ref.putData(processed.full, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        final progress = snap.bytesTransferred /
            (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        onProgress(progress);
      });
    }

    final snapshot = await task;
    final url = await snapshot.ref.getDownloadURL();

    String? thumbUrl;
    if (processed.thumb != null) {
      try {
        final thumbSnapshot =
            await thumbRef.putData(processed.thumb!, metadata);
        thumbUrl = await thumbSnapshot.ref.getDownloadURL();
      } catch (e) {
        debugPrint('StorageUploadService: thumbnail upload failed: $e');
      }
    }

    // Do NOT log the tokenized URL (grants unauthenticated read). Log path+size.
    debugPrint('StorageUploadService: uploaded ${ref.fullPath} '
        '(${(raw.length / 1024).round()}KB → ${(processed.full.length / 1024).round()}KB'
        '${processed.thumb != null ? ', thumb ${(processed.thumb!.length / 1024).round()}KB' : ''})');

    return (
      url: url,
      thumbUrl: thumbUrl,
      width: processed.width,
      height: processed.height,
    );
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
      final processed =
          await compute(_processImage, _ImageJob(raw, maxDim, _jpegQuality));
      clean = processed.full;
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

  /// Upload a chat voice message. Audio arrives already encoded/compressed
  /// by the recorder (AAC via `record`'s `AudioEncoder.aacLc`) — unlike
  /// [uploadChatImage] there is no isolate re-encode step, just a raw
  /// upload. Returns the download URL.
  ///
  /// [chatScopeId] is the same participant-scoping key documented on
  /// [uploadChatImage] (sorted "uidA_uidB" for a 1:1 chat, chatId for
  /// group) — `chat_audio/{scopeId}/` mirrors `chat_images/{scopeId}/`'s
  /// storage.rules predicate exactly (Faz 6).
  Future<String> uploadChatVoice({
    required String chatScopeId,
    required File audioFile,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('chat_audio/$chatScopeId/${ts}_${_randomId()}.m4a');
    await ref.putFile(audioFile, SettableMetadata(contentType: 'audio/mp4'));
    final url = await ref.getDownloadURL();
    debugPrint('StorageUploadService: uploaded ${ref.fullPath}');
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

  /// Delete a file by its bare Storage path — for objects with no direct
  /// download URL to begin with (`chat_media/` uploads, `read: false` in
  /// `storage.rules`, resolved only via the `getChatMediaUrl` callable's
  /// signed URL — see `uploadGroupChatMedia`'s doc comment). Best-effort,
  /// same as [deleteByUrl].
  Future<void> deleteByPath(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (e) {
      debugPrint('StorageUploadService.deleteByPath error: $e');
    }
  }
}
