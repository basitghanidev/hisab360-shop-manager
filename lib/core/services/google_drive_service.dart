import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All Google Drive interactions are here.
/// Architecture: sign-in → get Drive API → find/create folder → upload/download file.
class GoogleDriveService {
  // Drive file scope: only access files this app creates.
  GoogleSignIn? _googleSignInInstance;

  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn(
      scopes: [drive.DriveApi.driveFileScope],
    );
    return _googleSignInInstance!;
  }

  static const String _prefAccountEmail = 'google_drive_account_email';
  static const String _prefAccountName = 'google_drive_account_name';
  static const String _driveFolderName = 'Hisab360 Backups';
  static const String _backupFilename = 'hisab360_backup.json';

  // ─── Sign In ──────────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();

      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefAccountEmail, account.email);
        await prefs.setString(_prefAccountName, account.displayName ?? '');
        debugPrint('[DriveService] Signed in as ${account.email}');
      }

      return account;
    } on Exception catch (e) {
      final message = e.toString();
      debugPrint('[DriveService] Sign-in error: $message');

      if (message.contains('network_error') || message.contains('NetworkException')) {
        throw GoogleSignInException('No internet connection. Please connect to WiFi or mobile data and try again.');
      }
      if (message.contains('sign_in_cancelled') || message.contains('canceled')) {
        throw GoogleSignInException('Sign-in cancelled.');
      }
      if (message.contains('sign_in_failed') || message.contains('ApiException: 10')) {
        throw GoogleSignInException(
          'Configuration error: google-services.json is missing or has the wrong SHA-1 fingerprint.',
        );
      }
      throw GoogleSignInException('Sign-in failed: $message');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAccountEmail);
    await prefs.remove(_prefAccountName);
    debugPrint('[DriveService] Signed out.');
  }

  // ─── Account State ────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> get currentAccount async {
    try {
      return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<String?> get persistedEmail async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAccountEmail);
  }

  Future<String?> get persistedName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAccountName);
  }

  Future<bool> get isConfigured async {
    final email = await persistedEmail;
    return email != null && email.isNotEmpty;
  }

  // ─── Drive Operations ─────────────────────────────────────────────────────

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await currentAccount;
    if (account == null) return null;

    try {
      final authHeaders = await account.authHeaders;
      return drive.DriveApi(_AuthenticatedClient(authHeaders));
    } catch (e) {
      debugPrint('[DriveService] Failed to get auth headers: $e');
      return null;
    }
  }

  Future<String?> _getOrCreateAppFolder(drive.DriveApi api) async {
    try {
      final query = "name = '$_driveFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final list = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id, name)');

      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }

      final folder = drive.File()
        ..name = _driveFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder, $fields: 'id');
      debugPrint('[DriveService] Created Drive folder: ${created.id}');
      return created.id;
    } catch (e) {
      debugPrint('[DriveService] Folder access error: $e');
      final msg = e.toString();
      if (msg.contains('403') || msg.contains('disabled')) {
        throw GoogleDriveException(
          'Google Drive API is disabled for this project. '
          'Please visit the Google Cloud Console link in the instructions to enable it.',
        );
      }
      return null;
    }
  }

  Future<DriveUploadResult> uploadBackup(io.File file) async {
    final api = await _getDriveApi();
    if (api == null) return DriveUploadResult.failure('Not signed in to Google.');

    try {
      final folderId = await _getOrCreateAppFolder(api);
      if (folderId == null) {
        return DriveUploadResult.failure('Could not access or create the "Hisab360 Backups" folder. Please check permissions.');
      }

      final fileSize = await file.length();
      final media = drive.Media(file.openRead(), fileSize);

      final query = "name = '$_backupFilename' and '$folderId' in parents and trashed = false";
      final existing = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id)');

      if (existing.files != null && existing.files!.isNotEmpty) {
        final existingId = existing.files!.first.id!;
        await api.files.update(drive.File()..name = _backupFilename, existingId, uploadMedia: media);
        debugPrint('[DriveService] Updated existing backup: $existingId');
        return DriveUploadResult.success(isUpdate: true);
      } else {
        final newFile = drive.File()..name = _backupFilename..parents = [folderId];
        await api.files.create(newFile, uploadMedia: media);
        debugPrint('[DriveService] Created new backup.');
        return DriveUploadResult.success(isUpdate: false);
      }
    } catch (e) {
      debugPrint('[DriveService] Upload failed: $e');
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('authError')) {
        return DriveUploadResult.failure('Authentication expired. Please disconnect and reconnect your Google account.');
      }
      if (msg.contains('403') || msg.contains('forbidden')) {
        return DriveUploadResult.failure('Permission denied. Make sure Google Drive access is allowed for this app.');
      }
      if (msg.contains('SocketException') || msg.contains('network')) {
        return DriveUploadResult.failure('No internet connection during upload.');
      }
      return DriveUploadResult.failure('Upload failed: $msg');
    }
  }

  /// Downloads the latest backup file from Google Drive.
  Future<io.File?> downloadBackup() async {
    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final folderId = await _getOrCreateAppFolder(api);
      if (folderId == null) return null;

      final query = "name = '$_backupFilename' and '$folderId' in parents and trashed = false";
      final list = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id)');

      if (list.files == null || list.files!.isEmpty) return null;

      final fileId = list.files!.first.id!;
      final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final tempDir = await getTemporaryDirectory();
      final downloadFile = io.File('${tempDir.path}/drive_restore.json');
      
      final List<int> dataBytes = [];
      await for (final chunk in media.stream) {
        dataBytes.addAll(chunk);
      }
      await downloadFile.writeAsBytes(dataBytes);
      
      return downloadFile;
    } catch (e) {
      debugPrint('[DriveService] Download error: $e');
      return null;
    }
  }
}

// ─── Helper Classes ───────────────────────────────────────────────────────────

class GoogleDriveException implements Exception {
  final String message;
  const GoogleDriveException(this.message);
  @override
  String toString() => message;
}

class GoogleSignInException implements Exception {
  final String message;
  const GoogleSignInException(this.message);
  @override
  String toString() => message;
}

class DriveUploadResult {
  final bool success;
  final bool isUpdate;
  final String? errorMessage;
  const DriveUploadResult._({required this.success, this.isUpdate = false, this.errorMessage});
  factory DriveUploadResult.success({required bool isUpdate}) => DriveUploadResult._(success: true, isUpdate: isUpdate);
  factory DriveUploadResult.failure(String message) => DriveUploadResult._(success: false, errorMessage: message);
}

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _AuthenticatedClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
