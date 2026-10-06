import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:twin/controllers/app_controller.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'views/mainsplash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Get.put(AppController());
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

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
      home: SplashLogin(),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'controllers/app_controller.dart';
// import 'core/theme.dart';
// import 'views/login_view.dart';
// import 'views/mainsplash.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// // void main() {
// //   Get.put(AppController(), permanent: true);
// //   runApp(const TwinsApp());
// // }

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

// // void main() {
// //   Get.put(AppController(), permanent: true);
// //   runApp(GetMaterialApp(
// //     title: 'Twins Handyman',
// //     debugShowCheckedModeBanner: false,
// //     theme: buildTheme(),
// //     home: LoginView(),
// //   ));
// // }
