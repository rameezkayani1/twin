import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:twin/controllers/app_controller.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'views/mainsplash.dart';

/// Web client ID (Firebase Console > Authentication > Sign-in method > Google).
const _webClientId =
    '475067046837-v3bi84oep35kr0fgs8inf0j3dvdc4bf2.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // google_sign_in v7: initialize once, at startup.
  try {
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
  } catch (e) {
    debugPrint('Google Sign-In initialization error: $e');
  }

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
      home: const SplashLogin(),
    );
  }
}
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
