# SENTERY — GOOGLE DRIVE BACKUP FIX + ROUND 8 FIXES
## For: Claude Codex / GitHub Copilot / Cursor AI

---

> **ALL BUGS CONFIRMED BY SOURCE CODE READING.**
> Do not add new features. Fix exactly what is written. Run `flutter analyze` after every task.

---

## ROOT CAUSES FOUND (Summary Before Fixes)

| # | Bug | Root Cause File | Why It Happens |
|---|-----|-----------------|----------------|
| 1 | Google sign-in → nothing happens | `google_drive_service.dart` + Android config | No `google-services.json`, sign-in returns null silently |
| 2 | Drive sync opens share sheet instead | `backup_service.dart` | `exportBackup()` calls `Share.shareXFiles()` then returns path — Drive sync calls this same method |
| 3 | No feedback after connecting Google | `backup_screen.dart` | Account is null but no error message surfaced to user |
| 4 | Customer/wholesaler return payment shows wrong direction in ledger | `return_dao.dart` lines 121-122, 151-152 | Payment sub-entry uses `credit: amountPaidToday` when shop is PAYING them (should be `debit`) |
| 5 | Connected account forgotten on app restart | `backup_screen.dart` | No SharedPreferences persistence — relies only on `signInSilently()` which can fail |

---

## PART A — MANDATORY ANDROID SETUP (DO THIS FIRST — NOT CODE)

**The most important thing.** Without this, Google Sign-In will always return `null` on Android, no matter how good the code is.

### Step A1 — Create a Google Cloud Project

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com)
2. Click "New Project" → name it `sentery-shop` → Create
3. In the sidebar: **APIs & Services → Enable APIs**
4. Search for **Google Drive API** → Enable it

### Step A2 — Create OAuth Credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. Application type: **Android**
4. Package name: `com.example.possystem` (check `android/app/build.gradle` for your actual package name — use whatever `applicationId` says)
5. SHA-1 certificate fingerprint — run this command in your project root:

```bash
# For DEBUG builds (development testing):
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1

# For RELEASE builds (production):
keytool -list -v -keystore YOUR_RELEASE_KEYSTORE_PATH -alias YOUR_ALIAS -storepass YOUR_STORE_PASS | grep SHA1
```

6. Paste the SHA-1 fingerprint → Create
7. Download the `google-services.json` file

### Step A3 — Place `google-services.json`

Place the downloaded file at: **`android/app/google-services.json`**

This file is specific to your project — never commit it to a public GitHub repository.

### Step A4 — Update `android/app/build.gradle`

Confirm this plugin is applied (add if missing):

```gradle
apply plugin: 'com.google.gms.google-services'
```

### Step A5 — Update `android/build.gradle`

Confirm this dependency exists in the `dependencies` block (add if missing):

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.1'
}
```

---

## PART B — CODE FIXES (After Part A is done)

---

## TASK B1 — Split `BackupService.exportBackup()` Into Two Methods

**File:** `lib/core/services/backup_service.dart`

**Problem:** `exportBackup()` does two things: creates the file AND opens the OS share sheet. When `_handleCloudSync()` calls it, the share sheet pops up AND the Drive upload runs simultaneously — user sees a confusing share popup instead of a clean Drive upload.

**Fix:** Split into `createBackupFile()` (file only, no sharing) and `exportAndShare()` (file + share sheet). Everything else in the class stays exactly the same.

```dart
// ─── ADD this new method (no Share.shareXFiles call) ─────────────────────────
/// Creates the backup file and returns its path.
/// Does NOT open a share sheet. Used by Google Drive upload and unit tests.
Future<String> createBackupFile() async {
  final data = await _buildBackupPayload();
  final jsonString = jsonEncode(data);

  final String tempDir;
  if (testTempPath != null) {
    tempDir = testTempPath!;
  } else {
    final directory = await getTemporaryDirectory();
    tempDir = directory.path;
  }

  // Use a FIXED filename so each Drive sync overwrites the previous backup
  // instead of creating a new file every time (prevents Drive storage clutter).
  const filename = 'sentery_shop_backup.json';
  final file = File('$tempDir/$filename');
  await file.writeAsString(jsonString);
  return file.path;
}
// ─────────────────────────────────────────────────────────────────────────────

// ─── RENAME existing exportBackup() to exportAndShare() ──────────────────────
/// Creates the backup file AND opens the OS share sheet.
/// Used by the "Manual Backup & Share" button only.
Future<String> exportAndShare() async {
  final path = await createBackupFile();
  final file = File(path);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: 'Sentery Shop Backup — ${DateTime.now().toLocal().toString().split('.')[0]}',
  );

  return path;
}
// ─────────────────────────────────────────────────────────────────────────────

// ─── KEEP exportBackup() as an alias for backward compatibility ───────────────
// (Any other code that calls exportBackup() still works)
Future<String> exportBackup() => exportAndShare();
// ─────────────────────────────────────────────────────────────────────────────
```

---

## TASK B2 — Rewrite `GoogleDriveService` with Full Error Handling and Folder Management

**File:** `lib/core/services/google_drive_service.dart`

**Replace the entire file:**

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// All Google Drive interactions are here.
/// Architecture: sign-in → get Drive API → find/create folder → upload file.
class GoogleDriveService {
  // Drive file scope: only access files this app creates.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static const String _prefAccountEmail = 'google_drive_account_email';
  static const String _prefAccountName = 'google_drive_account_name';
  static const String _driveFolderName = 'Sentery Shop Backups';

  // ─── Sign In ──────────────────────────────────────────────────────────────

  /// Triggers the Google Sign-In flow.
  /// Returns the account on success, null on failure.
  /// Throws a [GoogleSignInException] with a readable message on known errors.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      // Force show account picker even if already signed in silently.
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();

      if (account != null) {
        // Persist account info so it survives app restarts.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefAccountEmail, account.email);
        await prefs.setString(_prefAccountName, account.displayName ?? '');
        debugPrint('[DriveService] Signed in as ${account.email}');
      }

      return account;
    } on Exception catch (e) {
      final message = e.toString();
      debugPrint('[DriveService] Sign-in error: $message');

      // Surface readable messages for common failure modes.
      if (message.contains('network_error') || message.contains('NetworkException')) {
        throw GoogleSignInException('No internet connection. Please connect to WiFi or mobile data and try again.');
      }
      if (message.contains('sign_in_cancelled') || message.contains('canceled')) {
        throw GoogleSignInException('Sign-in cancelled.');
      }
      if (message.contains('sign_in_failed') || message.contains('ApiException: 10')) {
        throw GoogleSignInException(
          'Configuration error: google-services.json is missing or has the wrong SHA-1 fingerprint. '
          'See setup instructions in the Codex document.',
        );
      }
      throw GoogleSignInException('Sign-in failed: $message');
    }
  }

  /// Sign out and clear persisted account info.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAccountEmail);
    await prefs.remove(_prefAccountName);
    debugPrint('[DriveService] Signed out.');
  }

  // ─── Account State ────────────────────────────────────────────────────────

  /// Returns the currently signed-in account, or tries a silent sign-in.
  /// Never throws — returns null if not signed in.
  Future<GoogleSignInAccount?> get currentAccount async {
    try {
      return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  /// Returns the persisted email (shown even when silent sign-in fails).
  Future<String?> get persistedEmail async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAccountEmail);
  }

  /// Returns the persisted display name.
  Future<String?> get persistedName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAccountName);
  }

  /// True if we have persisted credentials (user was signed in before).
  Future<bool> get isConfigured async {
    final email = await persistedEmail;
    return email != null && email.isNotEmpty;
  }

  // ─── Drive Operations ─────────────────────────────────────────────────────

  /// Gets an authenticated Drive API client, or null if not signed in.
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

  /// Finds the "Sentery Shop Backups" folder on Drive, creating it if needed.
  Future<String?> _getOrCreateAppFolder(drive.DriveApi api) async {
    try {
      // Search for existing folder
      final query =
          "name = '$_driveFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final list = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id, name)');

      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }

      // Create the folder
      final folder = drive.File()
        ..name = _driveFolderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder, $fields: 'id');
      debugPrint('[DriveService] Created Drive folder: ${created.id}');
      return created.id;
    } catch (e) {
      debugPrint('[DriveService] Folder error: $e');
      return null;
    }
  }

  /// Uploads a backup file to the "Sentery Shop Backups" folder.
  /// If a file with the same name already exists in the folder, it is REPLACED
  /// (so Drive doesn't accumulate hundreds of backup files).
  ///
  /// Returns a [DriveUploadResult] describing what happened.
  Future<DriveUploadResult> uploadBackup(File file) async {
    final api = await _getDriveApi();
    if (api == null) {
      return DriveUploadResult.failure('Not signed in to Google Drive.');
    }

    try {
      final folderId = await _getOrCreateAppFolder(api);
      if (folderId == null) {
        return DriveUploadResult.failure('Could not access or create the backup folder on Google Drive.');
      }

      final filename = 'sentery_shop_backup.json';
      final fileSize = await file.length();
      final media = drive.Media(file.openRead(), fileSize);

      // Check if a backup file already exists in the folder.
      final query = "name = '$filename' and '$folderId' in parents and trashed = false";
      final existing = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id)');

      String? uploadedFileId;
      if (existing.files != null && existing.files!.isNotEmpty) {
        // Update the existing file (no new file created).
        final existingId = existing.files!.first.id!;
        final updated = await api.files.update(
          drive.File()..name = filename,
          existingId,
          uploadMedia: media,
          $fields: 'id',
        );
        uploadedFileId = updated.id;
        debugPrint('[DriveService] Updated existing backup: $existingId');
        return DriveUploadResult.success(isUpdate: true, fileId: uploadedFileId);
      } else {
        // Create new file in the folder.
        final newFile = drive.File()
          ..name = filename
          ..parents = [folderId];
        final created = await api.files.create(
          newFile,
          uploadMedia: media,
          $fields: 'id',
        );
        uploadedFileId = created.id;
        debugPrint('[DriveService] Created new backup: $uploadedFileId');
        return DriveUploadResult.success(isUpdate: false, fileId: uploadedFileId);
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
}

// ─── Helper Classes ───────────────────────────────────────────────────────────

class GoogleSignInException implements Exception {
  final String message;
  const GoogleSignInException(this.message);
  @override
  String toString() => message;
}

class DriveUploadResult {
  final bool success;
  final bool isUpdate;
  final String? fileId;
  final String? errorMessage;

  const DriveUploadResult._({
    required this.success,
    this.isUpdate = false,
    this.fileId,
    this.errorMessage,
  });

  factory DriveUploadResult.success({required bool isUpdate, String? fileId}) =>
      DriveUploadResult._(success: true, isUpdate: isUpdate, fileId: fileId);

  factory DriveUploadResult.failure(String message) =>
      DriveUploadResult._(success: false, errorMessage: message);
}

/// HTTP client that injects Google auth headers into every request.
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
```

---

## TASK B3 — Rewrite `BackupScreen` with Full Drive UX

**File:** `lib/features/backup/screens/backup_screen.dart`

**Replace the entire file:**

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/services/backup_service.dart';
import 'package:sentery_app/core/services/google_drive_service.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:shared_preferences/shared_preferences.dart';

final googleDriveServiceProvider = Provider<GoogleDriveService>((_) => GoogleDriveService());

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isWorking = false;
  String? _workingLabel;
  String? _persistedEmail;
  String? _persistedName;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    final service = ref.read(googleDriveServiceProvider);
    final email = await service.persistedEmail;
    final name = await service.persistedName;
    final prefs = await SharedPreferences.getInstance();
    final syncTime = prefs.getString('last_drive_sync');

    if (mounted) {
      setState(() {
        _persistedEmail = email;
        _persistedName = name;
        _lastSyncTime = syncTime;
      });
    }
  }

  void _setWorking(bool working, {String? label}) {
    if (mounted) setState(() { _isWorking = working; _workingLabel = label; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Backup & Restore',
          urdu: 'Data Mehfooz Karein',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── NOTE BANNER ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Unsaved bill drafts are not included in backups. '
                          'Complete any open bill before restoring.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── GOOGLE DRIVE SECTION ─────────────────────────────────
                _buildDriveSection(),
                const SizedBox(height: 16),

                // ─── MANUAL EXPORT ────────────────────────────────────────
                _buildManualExportCard(),
                const SizedBox(height: 16),

                // ─── RESTORE ─────────────────────────────────────────────
                _buildRestoreCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // ─── LOADING OVERLAY ─────────────────────────────────────────────
          if (_isWorking)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _workingLabel ?? 'Please wait...',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── DRIVE SECTION ─────────────────────────────────────────────────────────

  Widget _buildDriveSection() {
    final isConnected = _persistedEmail != null && _persistedEmail!.isNotEmpty;

    return AppCard(
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.cloud_sync, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text('Google Drive Backup', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 12),

          if (!isConnected) ...[
            // ── NOT CONNECTED ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Connect your Google account to back up your shop data to Google Drive — '
                'just like WhatsApp backs up your chats.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : _handleSignIn,
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text('Connect Google Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            // ── CONNECTED ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.success,
                    radius: 18,
                    child: Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _persistedName?.isNotEmpty == true ? _persistedName! : 'Connected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          _persistedEmail!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (_lastSyncTime != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Last sync: $_lastSyncTime',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],

            // Sync Now button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : _handleDriveSync,
                icon: const Icon(Icons.backup, color: Colors.white),
                label: const Text('Backup to Drive Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Disconnect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isWorking ? null : _handleSignOut,
                icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                label: const Text('Disconnect Account', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── MANUAL EXPORT ──────────────────────────────────────────────────────────

  Widget _buildManualExportCard() {
    return AppCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.share, color: Colors.teal, size: 28),
              SizedBox(width: 10),
              Text('Manual Backup & Share', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Export your shop data as a JSON file and share it via WhatsApp, Email, or save locally.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isWorking ? null : _handleManualExport,
              icon: const Icon(Icons.ios_share, color: Colors.white),
              label: const Text('Export & Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESTORE ────────────────────────────────────────────────────────────────

  Widget _buildRestoreCard() {
    return AppCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.restore, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Restore from File', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a previously exported .json backup file to restore all shop data.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
          const Text(
            '⚠️  WARNING: This will DELETE all current data!',
            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isWorking ? null : _handleFileRestore,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Select Backup File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HANDLERS ───────────────────────────────────────────────────────────────

  Future<void> _handleSignIn() async {
    _setWorking(true, label: 'Connecting to Google...');
    try {
      final account = await ref.read(googleDriveServiceProvider).signIn();

      if (account != null) {
        // Reload persisted state from SharedPreferences.
        await _loadPersistedState();

        if (mounted) {
          _showSnackBar(
            'Connected: ${account.email}',
            color: AppColors.success,
            icon: Icons.check_circle,
          );
        }
      } else {
        // Account is null but no exception was thrown — this usually means
        // the user dismissed the picker without selecting an account.
        if (mounted) {
          _showSnackBar('Sign-in cancelled — no account was selected.', color: Colors.orange);
        }
      }
    } on GoogleSignInException catch (e) {
      if (mounted) _showSnackBar(e.message, color: AppColors.danger, duration: 6);
    } catch (e) {
      if (mounted) _showSnackBar('Unexpected error: $e', color: AppColors.danger, duration: 6);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google Account?'),
        content: Text(
          'You will no longer be able to sync to Google Drive.\n\n'
          'Connected: ${_persistedEmail ?? ""}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(googleDriveServiceProvider).signOut();
    await _loadPersistedState();

    if (mounted) _showSnackBar('Google account disconnected.', color: Colors.grey);
  }

  Future<void> _handleDriveSync() async {
    _setWorking(true, label: 'Preparing backup data...');
    try {
      final db = ref.read(databaseProvider);

      // Step 1: Create backup file (no share sheet).
      final path = await BackupService(db).createBackupFile();

      _setWorking(true, label: 'Uploading to Google Drive...');

      // Step 2: Upload to Drive.
      final result = await ref.read(googleDriveServiceProvider).uploadBackup(File(path));

      if (result.success) {
        // Save sync time.
        final syncTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_drive_sync', syncTimeStr);
        await _loadPersistedState();

        if (mounted) {
          _showSnackBar(
            result.isUpdate
                ? '✅ Backup updated on Google Drive!'
                : '✅ New backup created on Google Drive!',
            color: AppColors.success,
            duration: 5,
          );
        }
      } else {
        if (mounted) {
          _showSnackBar(
            '❌ ${result.errorMessage ?? "Upload failed."}',
            color: AppColors.danger,
            duration: 8,
          );
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Sync error: $e', color: AppColors.danger, duration: 6);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleManualExport() async {
    _setWorking(true, label: 'Preparing backup...');
    try {
      final db = ref.read(databaseProvider);
      await BackupService(db).exportAndShare(); // Opens share sheet
    } catch (e) {
      if (mounted) _showSnackBar('Export failed: $e', color: AppColors.danger);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleFileRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('Confirm Restore'),
        ]),
        content: const Text(
          'This will permanently DELETE all current data and replace it with the backup file.\n\n'
          'This cannot be undone. Are you absolutely sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Restore Everything', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _setWorking(true, label: 'Restoring data...');
    try {
      final file = File(result.files.single.path!);
      final db = ref.read(databaseProvider);
      await BackupService(db).restoreBackup(file);

      if (mounted) {
        _showSnackBar(
          '✅ Restore successful! Please restart the app for changes to take effect.',
          color: AppColors.success,
          duration: 8,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Restore failed: $e', color: AppColors.danger, duration: 6);
    } finally {
      _setWorking(false);
    }
  }

  void _showSnackBar(String message, {Color color = AppColors.primary, int duration = 3, IconData? icon}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
```

---

## TASK B4 — Fix Return Payment Ledger Entries (Customer + Wholesaler)

**File:** `lib/core/database/daos/return_dao.dart`

**Problem:** When a customer/wholesaler return includes an immediate cash payment today (`amountPaidToday > 0`), the secondary ledger entry for the payment portion records:
```dart
debit: const Value(0),
credit: Value(amountPaidToday),   // ← WRONG: implies customer paid us
```
But for a customer/wholesaler return, WE are paying THEM (money out). Should be:
```dart
debit: Value(amountPaidToday),    // ← CORRECT: money going out from shop
credit: const Value(0),
```

**Fix — Wholesaler return payment block (around line 121-122):**

```dart
// BEFORE:
if (amountPaidToday > 0) {
  await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
    partyType: 'wholesaler',
    partyId: wId,
    entryType: 'payment',
    debit: const Value(0),           // ← WRONG
    credit: Value(amountPaidToday),  // ← WRONG
    balanceAfter: Value(newBalance),
    invoiceId: Value(invoiceId),
    paymentId: Value(paymentId),
  ));
}

// AFTER:
if (amountPaidToday > 0) {
  await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
    partyType: 'wholesaler',
    partyId: wId,
    entryType: 'payment',
    debit: Value(amountPaidToday),  // ← CORRECT: shop paid wholesaler
    credit: const Value(0),
    balanceAfter: Value(newBalance),
    invoiceId: Value(invoiceId),
    paymentId: Value(paymentId),
  ));
}
```

**Apply the identical fix to the Customer return payment block (around line 151-152):**

```dart
// BEFORE:
if (amountPaidToday > 0) {
  await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
    partyType: 'customer',
    partyId: cId,
    entryType: 'payment',
    debit: const Value(0),           // ← WRONG
    credit: Value(amountPaidToday),  // ← WRONG
    balanceAfter: Value(newBalance),
    invoiceId: Value(invoiceId),
    paymentId: Value(paymentId),
  ));
}

// AFTER:
if (amountPaidToday > 0) {
  await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
    partyType: 'customer',
    partyId: cId,
    entryType: 'payment',
    debit: Value(amountPaidToday),  // ← CORRECT: shop paid customer
    credit: const Value(0),
    balanceAfter: Value(newBalance),
    invoiceId: Value(invoiceId),
    paymentId: Value(paymentId),
  ));
}
```

Do NOT change the Supplier return payment block (lines 91-92) — that one correctly uses `debit: Value(amountPaidToday)` already.

---

## TASK B5 — Final `flutter analyze` Pass and Verification

```bash
# 1. Rebuild generated code
flutter pub run build_runner build --delete-conflicting-outputs

# 2. Static analysis — must be zero errors
flutter analyze

# 3. Build release APK
flutter build apk --release

# 4. Install on device
flutter install
```

---

## MANUAL VERIFICATION AFTER INSTALL

### Google Drive Flow (Test on Real Device — Emulator May Not Support)

```
□ STEP 1: Connect account
  → Backup & Restore → tap "Connect Google Account"
  → Loading overlay appears with "Connecting to Google..."
  → Google account picker opens
  → Select your Google account
  → Screen returns: green success banner shows "Connected: your@email.com"
  → The card changes to show your name and email with a green checkmark
  → "Backup to Drive Now" and "Disconnect Account" buttons appear

□ STEP 2: Backup to Drive
  → Tap "Backup to Drive Now"
  → Loading overlay: "Preparing backup data..." then "Uploading to Google Drive..."
  → Success banner: "✅ New backup created on Google Drive!" (first time)
    OR "✅ Backup updated on Google Drive!" (subsequent times)
  → "Last sync: [date & time]" appears under account info
  → Open Google Drive on your phone → verify "Sentery Shop Backups" folder exists
  → Tap the folder → verify "sentery_shop_backup.json" is inside

□ STEP 3: Run sync again
  → Tap "Backup to Drive Now" again
  → SUCCESS: says "Backup updated" NOT "New backup created"
  → Google Drive still has only ONE file (not two — no clutter)

□ STEP 4: Disconnect
  → Tap "Disconnect Account"
  → Confirmation dialog appears
  → Confirm → card changes back to "Connect Google Account" state

□ STEP 5: App restart persistence
  → Connect account → close app completely → reopen
  → Backup screen still shows the connected account (email + name visible)
  → Does NOT require re-login (uses signInSilently)
```

### Return Payment Direction (Test after Task B4)

```
□ Customer returns goods worth Rs. 5,000, pays Rs. 2,000 at return time
  → Open customer profile → Ledger tab
  → Return entry: RED, "Maal Wapsi — Hum Ne Dena Hai"
  → Payment entry below it: shows refund paid — NOT shown as "Wasooli (Received)"
  → Final balance: -3,000 paisa × 100 = -Rs. 3,000 (shop still owes Rs. 3,000)
```

---

## IF GOOGLE SIGN-IN STILL RETURNS NULL AFTER PART A SETUP

This means one of:
1. Wrong SHA-1 fingerprint in Cloud Console (use debug SHA-1 for debug builds, release SHA-1 for release APK)
2. Wrong package name in Cloud Console vs `android/app/build.gradle`
3. `google-services.json` was not placed in `android/app/` (not `android/`, must be in `android/app/`)
4. OAuth consent screen not configured in Cloud Console (go to APIs & Services → OAuth consent screen)

Check the error that appears in the snackbar after attempting sign-in — the new code shows a specific message for each of these cases (ApiException 10 = config error, network_error = no internet, cancelled = user dismissed).

---

*Document Version 8.0 — Google Drive Backup + Return Payment Fix*
*5 confirmed bugs, 4 code tasks, 1 mandatory Android setup section.*
*All bugs traced to exact file and line. No new features added.*
