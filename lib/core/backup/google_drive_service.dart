import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser;
  }

  Future<drive.DriveApi?> _getDriveApi({bool allowInteractiveAuth = false}) async {
    GoogleSignInAccount? account = _currentUser ?? await signInSilently();
    account ??=
        allowInteractiveAuth ? await _googleSignIn.signIn() : null;
    if (account == null) return null;
    _currentUser = account;

    try {
      final headers = await account.authHeaders;
      return drive.DriveApi(_GoogleAuthClient(headers));
    } catch (_) {
      if (!allowInteractiveAuth) rethrow;
      await _googleSignIn.signOut();
      final refreshed = await _googleSignIn.signIn();
      if (refreshed == null) return null;
      _currentUser = refreshed;
      final headers = await refreshed.authHeaders;
      return drive.DriveApi(_GoogleAuthClient(headers));
    }
  }

  Future<String?> uploadBackup(
    String filePath, {
    bool allowInteractiveAuth = true,
  }) async {
    final driveApi =
        await _getDriveApi(allowInteractiveAuth: allowInteractiveAuth);
    if (driveApi == null)
      throw Exception('Google Drive se connect nahi ho sake.');

    final file = File(filePath);
    final fileName = p.basename(filePath);

    final driveFile = drive.File();
    driveFile.name = fileName;
    driveFile.parents = ['appDataFolder'];

    final media = drive.Media(file.openRead(), file.lengthSync());

    final result = await driveApi.files.create(driveFile, uploadMedia: media);
    return result.id;
  }

  Future<List<drive.File>> listBackups({bool allowInteractiveAuth = true}) async {
    final driveApi =
        await _getDriveApi(allowInteractiveAuth: allowInteractiveAuth);
    if (driveApi == null)
      throw Exception('Google Drive se connect nahi ho sake.');

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id, name, createdTime, size)',
      orderBy: 'createdTime desc',
    );

    return fileList.files ?? [];
  }

  Future<void> downloadBackup(
    String fileId,
    String savePath, {
    bool allowInteractiveAuth = true,
  }) async {
    final driveApi =
        await _getDriveApi(allowInteractiveAuth: allowInteractiveAuth);
    if (driveApi == null)
      throw Exception('Google Drive se connect nahi ho sake.');

    final drive.Media media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final saveFile = File(savePath);
    final List<int> dataStore = [];
    await for (final data in media.stream) {
      dataStore.addAll(data);
    }
    await saveFile.writeAsBytes(dataStore);
  }

  static const _prefAutoUploadToDrive = 'auto_upload_to_drive';

  static Future<bool> isAutoUploadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoUploadToDrive) ?? false;
  }

  static Future<void> setAutoUploadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoUploadToDrive, enabled);
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
