import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_page.dart'; // UserModel lives here

/// Loads the logged-in user's saved registration details from Firestore.
///
/// Usage in your Profile page:
///
///   final p = Get.put(ProfileController());
///
///   Obx(() {
///     if (p.isLoading.value) return const CircularProgressIndicator();
///     final user = p.user.value;
///     if (user == null) return const Text('No profile found');
///     return Column(children: [
///       Text(user.name),
///       Text(user.email),
///       Text(user.phone),
///     ]);
///   });
class ProfileController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final user = Rxn<UserModel>();
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) user.value = UserModel.fromMap(doc.data()!);
    } finally {
      isLoading.value = false;
    }
  }

  /// Optional: update name/phone from the profile screen
  Future<void> updateProfile({String? name, String? phone}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).update({
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    });
    await loadProfile();
  }
}
