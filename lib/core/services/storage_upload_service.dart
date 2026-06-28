import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Handles all Firebase Storage uploads.
/// Paths:
///   - profile_photos/{uid}        (overwrites on update)
///   - post_images/{uid}/{ts}.jpg  (unique per upload)
class StorageUploadService {
  static final StorageUploadService _instance =
      StorageUploadService._internal();
  factory StorageUploadService() => _instance;
  StorageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a profile photo. Returns the public download URL.
  /// Overwrites any existing photo for the user (single file per uid).
  Future<String> uploadProfilePhoto({
    required String userId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child('profile_photos/$userId.jpg');
    return _upload(ref, imageFile, onProgress);
  }

  /// Upload a community post image. Returns the public download URL.
  Future<String> uploadPostImage({
    required String userId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('post_images/$userId/$ts.jpg');
    return _upload(ref, imageFile, onProgress);
  }

  /// Upload a chat image message. Returns the public download URL.
  Future<String> uploadChatImage({
    required String userId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('chat_images/$userId/$ts.jpg');
    return _upload(ref, imageFile, onProgress);
  }

  Future<String> _upload(
    Reference ref,
    File file,
    void Function(double)? onProgress,
  ) async {
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = ref.putFile(file, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        final progress =
            snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        onProgress(progress);
      });
    }

    final snapshot = await task;
    final url = await snapshot.ref.getDownloadURL();
    debugPrint('StorageUploadService: uploaded to $url');
    return url;
  }

  /// Upload a gym logo. Returns the public download URL.
  /// Overwrites any existing logo for the gym (single file per gymId).
  Future<String> uploadGymLogo({
    required String gymId,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child('gyms/$gymId/logo.jpg');
    return _upload(ref, imageFile, onProgress);
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
