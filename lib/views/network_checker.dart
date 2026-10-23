// import 'dart:async';

// import 'package:get/get.dart';
// import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

// /// Tracks REAL internet access (not just "Wi-Fi is on").
// /// - Listens live, so the UI reacts the moment the connection drops/returns.
// /// - [check] can be awaited before any action that needs the network.
// class NetworkController extends GetxController {
//   /// Start as `true` so the offline banner doesn't flash on launch.
//   final isOnline = true.obs;

//   /// True while a manual check is running (used for loading states).
//   final isChecking = false.obs;

//   StreamSubscription<InternetStatus>? _sub;

//   @override
//   void onInit() {
//     super.onInit();
//     check();
//     _sub = InternetConnection().onStatusChange.listen(
//       (status) => isOnline.value = status == InternetStatus.connected,
//     );
//   }

//   /// Actively tests for internet access. Returns `true` if online.
//   Future<bool> check() async {
//     isChecking.value = true;
//     try {
//       isOnline.value = await InternetConnection().hasInternetAccess;
//     } catch (_) {
//       isOnline.value = false;
//     } finally {
//       isChecking.value = false;
//     }
//     return isOnline.value;
//   }

//   @override
//   void onClose() {
//     _sub?.cancel();
//     super.onClose();
//   }
// }
