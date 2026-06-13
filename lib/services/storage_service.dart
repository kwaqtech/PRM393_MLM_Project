import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Wrapper around Firebase Storage for uploading and managing images.
/// Used for book cover images and user avatars.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Upload a file (book cover or avatar) and return the download URL.
  ///
  /// [file] is the local file to upload.
  /// [folder] is the storage folder (e.g. 'book_covers' or 'avatars').
  Future<String> uploadImage({
    required File file,
    required String folder,
  }) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child(folder).child(fileName);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Upload a book cover image. Returns the download URL.
  Future<String> uploadBookCover(File file) async {
    return uploadImage(file: file, folder: 'book_covers');
  }

  /// Upload a user avatar image. Returns the download URL.
  Future<String> uploadAvatar(File file) async {
    return uploadImage(file: file, folder: 'avatars');
  }

  /// Delete an image by its download URL.
  /// Silently catches errors if the file doesn't exist.
  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // File may already be deleted or URL may be invalid — ignore.
    }
  }
}
