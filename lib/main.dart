import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/app_controller.dart';
import 'core/theme.dart';
import 'views/login_view.dart';
import 'views/mainsplash.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  Get.put(AppController(), permanent: true);
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

// void main() {
//   Get.put(AppController(), permanent: true);
//   runApp(GetMaterialApp(
//     title: 'Twins Handyman',
//     debugShowCheckedModeBanner: false,
//     theme: buildTheme(),
//     home: LoginView(),
//   ));
// }
