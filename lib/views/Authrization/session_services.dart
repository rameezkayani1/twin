import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

/// Saves the login session in the local database (GetStorage).
/// NEVER store the password here.
class SessionService {
  SessionService._();

  static final _box = GetStorage();

  static const _kLoggedIn = 'is_logged_in';
  static const _kUid = 'uid';
  static const _kEmail = 'email';
  static const _kName = 'name';
  static const _kPhoto = 'photo';
  static const _kProvider = 'provider'; // google.com / password

  /// Call once in main() after GetStorage.init().
  /// Keeps the local DB in sync with Firebase automatically.
  static void listen() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        save(user);
      } else {
        clear();
      }
    });
  }

  static Future<void> save(User user) async {
    await _box.write(_kLoggedIn, true);
    await _box.write(_kUid, user.uid);
    await _box.write(_kEmail, user.email);
    await _box.write(_kName, user.displayName);
    await _box.write(_kPhoto, user.photoURL);
    await _box.write(
      _kProvider,
      user.providerData.isNotEmpty ? user.providerData.first.providerId : null,
    );
  }

  /// Clears the session but keeps 'last_email' (used to prefill the login form).
  static Future<void> clear() async {
    for (final k in [_kLoggedIn, _kUid, _kEmail, _kName, _kPhoto, _kProvider]) {
      await _box.remove(k);
    }
  }

  static bool get isLoggedIn => _box.read<bool>(_kLoggedIn) ?? false;
  static String? get uid => _box.read<String>(_kUid);
  static String? get email => _box.read<String>(_kEmail);
  static String? get name => _box.read<String>(_kName);
  static String? get photo => _box.read<String>(_kPhoto);
  static String? get provider => _box.read<String>(_kProvider);
}
