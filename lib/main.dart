import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:twin/controllers/app_controller.dart';
import 'package:twin/views/Authrization/session_services.dart';
import 'package:twin/views/shell_view.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'views/mainsplash.dart';

const _webClientId =
    '475067046837-v3bi84oep35kr0fgs8inf0j3dvdc4bf2.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local database must be ready before anything reads the session.
  await GetStorage.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  try {
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
  } catch (e) {
    debugPrint('Google Sign-In initialization error: $e');
  }

  // Keep local DB in sync with Firebase (save on login, clear on logout).
  SessionService.listen();

  Get.put(AppController());

  runApp(const TwinsApp());
}

class TwinsApp extends StatelessWidget {
  const TwinsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Twins Handyman',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Chooses the first screen using the saved local session,
/// then follows Firebase for live changes (e.g. logout).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase says logged in
        if (snapshot.hasData) return const ShellView();

        // Firebase still restoring -> trust the local database (instant start)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SessionService.isLoggedIn
              ? const ShellView()
              : const SplashLogin();
        }

        // Firebase finished and there is no user
        return const SplashLogin();
      },
    );
  }
}

/// Call from your logout button: `await signOutUser();`
Future<void> signOutUser() async {
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
  await FirebaseAuth.instance.signOut();
  await SessionService.clear();
  Get.offAll(() => const SplashLogin());
}
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:twin/controllers/app_controller.dart';

// import 'firebase_options.dart';
// import 'core/theme.dart';
// import 'views/mainsplash.dart';

// /// Web client ID (Firebase Console > Authentication > Sign-in method > Google).
// const _webClientId =
//     '475067046837-v3bi84oep35kr0fgs8inf0j3dvdc4bf2.apps.googleusercontent.com';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//   } catch (e) {
//     debugPrint('Firebase initialization error: $e');
//   }

//   // google_sign_in v7: initialize once, at startup.
//   try {
//     await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
//   } catch (e) {
//     debugPrint('Google Sign-In initialization error: $e');
//   }

//   Get.put(AppController());

//   runApp(const TwinsApp());
// }

// class TwinsApp extends StatelessWidget {
//   const TwinsApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       title: 'Twins Handyman',
//       debugShowCheckedModeBanner: false,
//       theme: buildTheme(),
//       home: const SplashLogin(),
//     );
//   }
// }
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:twin/controllers/app_controller.dart';

// import 'firebase_options.dart';
// import 'core/theme.dart';
// import 'views/mainsplash.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//     Get.put(AppController());
//   } catch (e) {
//     debugPrint('Firebase initialization error: $e');
//   }

//   runApp(const TwinsApp());
// }

// class TwinsApp extends StatelessWidget {
//   const TwinsApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       title: 'Twins Handyman',
//       debugShowCheckedModeBanner: false,
//       theme: buildTheme(),
//       home: SplashLogin(),
//     );
//   }
// }
