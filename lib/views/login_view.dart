// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import '../core/theme.dart';
// // import '../core/widgets.dart';
// // import 'shell_view.dart';

// // class LoginView extends StatelessWidget {
// //   LoginView({super.key});
// //   final signUp = false.obs;
// //   void _go() => Get.offAll(() => const ShellView());

// //   @override
// //   Widget build(BuildContext context) => Scaffold(
// //     backgroundColor: C.ink,
// //     body: SafeArea(
// //       child: Center(
// //         child: SingleChildScrollView(
// //           padding: const EdgeInsets.all(24),
// //           child: ConstrainedBox(
// //             constraints: const BoxConstraints(maxWidth: 440),
// //             child: Obx(
// //               () => Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Row(
// //                     children: [
// //                       Container(
// //                         width: 48,
// //                         height: 48,
// //                         decoration: BoxDecoration(
// //                           color: C.orange,
// //                           borderRadius: BorderRadius.circular(14),
// //                         ),
// //                         child: const Icon(Icons.handyman, color: C.ink),
// //                       ),
// //                       const SizedBox(width: 12),
// //                       const Text(
// //                         'Twins Handyman llc',
// //                         style: TextStyle(
// //                           color: Colors.white,
// //                           fontWeight: FontWeight.w800,
// //                           fontSize: 22,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   gap(32),
// //                   Text(
// //                     signUp.value ? 'Create your account' : 'Welcome back',
// //                     style: const TextStyle(
// //                       color: Colors.white,
// //                       fontWeight: FontWeight.w800,
// //                       fontSize: 28,
// //                     ),
// //                   ),
// //                   gap(6),
// //                   const Text(
// //                     'North Jersey & Staten Island',
// //                     style: TextStyle(color: Color(0xFFB9BFC6)),
// //                   ),
// //                   gap(24),
// //                   Container(
// //                     padding: const EdgeInsets.all(20),
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: BorderRadius.circular(18),
// //                     ),
// //                     child: Column(
// //                       children: [
// //                         if (signUp.value) ...[
// //                           _f('Full name', Icons.person_outline),
// //                           gap(),
// //                         ],
// //                         _f('Email', Icons.mail_outline),
// //                         gap(),
// //                         if (signUp.value) ...[
// //                           _f('Phone', Icons.call_outlined),
// //                           gap(),
// //                         ],
// //                         _f('Password', Icons.lock_outline, obscure: true),
// //                         gap(16),
// //                         cta(signUp.value ? 'Create account' : 'Log in', _go),
// //                         gap(10),
// //                         Row(
// //                           children: [
// //                             Expanded(
// //                               child: OutlinedButton.icon(
// //                                 onPressed: _go,
// //                                 icon: const Icon(Icons.apple),
// //                                 label: const Text('Apple'),
// //                               ),
// //                             ),
// //                             const SizedBox(width: 10),
// //                             Expanded(
// //                               child: OutlinedButton.icon(
// //                                 onPressed: _go,
// //                                 icon: const Icon(Icons.g_mobiledata, size: 28),
// //                                 label: const Text('Google'),
// //                               ),
// //                             ),
// //                           ],
// //                         ),
// //                         if (!signUp.value)
// //                           TextButton(
// //                             onPressed: _recover,
// //                             child: const Text(
// //                               'Forgot password?',
// //                               style: TextStyle(color: C.soft),
// //                             ),
// //                           ),
// //                       ],
// //                     ),
// //                   ),
// //                   gap(8),
// //                   Center(
// //                     child: TextButton(
// //                       onPressed: () => signUp.toggle(),
// //                       child: Text(
// //                         signUp.value
// //                             ? 'Have an account? Log in'
// //                             : 'New here? Sign up',
// //                         style: const TextStyle(
// //                           color: C.orange,
// //                           fontWeight: FontWeight.w700,
// //                         ),
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     ),
// //   );

// //   Widget _f(String l, IconData i, {bool obscure = false}) => TextField(
// //     obscureText: obscure,
// //     decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20)),
// //   );

// //   void _recover() => Get.defaultDialog(
// //     title: 'Reset password',
// //     content: const Padding(
// //       padding: EdgeInsets.all(8),
// //       child: TextField(decoration: InputDecoration(labelText: 'Email')),
// //     ),
// //     textConfirm: 'Send link',
// //     confirmTextColor: Colors.white,
// //     buttonColor: C.orange,
// //     textCancel: 'Cancel',
// //     onConfirm: () {
// //       Get.back();
// //       toast('Reset link sent (demo)');
// //     },
// //   );
// // }

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../core/theme.dart';
// import '../core/widgets.dart';
// import 'shell_view.dart';

// class AuthController extends GetxController {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Form
//   final emailController = TextEditingController();
//   final passwordController = TextEditingController();
//   final nameController = TextEditingController();
//   final phoneController = TextEditingController();

//   final isLoading = false.obs;
//   final signUp = false.obs;
//   final obscurePassword = true.obs;

//   // =========================
//   // LOGIN
//   // =========================
//   Future<void> login() async {
//     if (emailController.text.trim().isEmpty ||
//         passwordController.text.isEmpty) {
//       _error('Please enter email and password');
//       return;
//     }

//     try {
//       isLoading.value = true;

//       await _auth.signInWithEmailAndPassword(
//         email: emailController.text.trim(),
//         password: passwordController.text.trim(),
//       );

//       Get.offAll(() => const ShellView());
//     } on FirebaseAuthException catch (e) {
//       _error(_firebaseError(e.code));
//     } catch (e) {
//       _error('Something went wrong. Please try again.');
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   // =========================
//   // SIGN UP
//   // =========================
//   Future<void> createAccount() async {
//     if (nameController.text.trim().isEmpty ||
//         emailController.text.trim().isEmpty ||
//         phoneController.text.trim().isEmpty ||
//         passwordController.text.isEmpty) {
//       _error('Please fill all fields');
//       return;
//     }

//     if (passwordController.text.length < 6) {
//       _error('Password must be at least 6 characters');
//       return;
//     }

//     try {
//       isLoading.value = true;

//       // Create Firebase Authentication account
//       final credential = await _auth.createUserWithEmailAndPassword(
//         email: emailController.text.trim(),
//         password: passwordController.text.trim(),
//       );

//       final user = credential.user;

//       if (user != null) {
//         // Save display name in Firebase Auth
//         await user.updateDisplayName(nameController.text.trim());

//         // Save extra user information in Firestore
//         await _firestore.collection('users').doc(user.uid).set({
//           'uid': user.uid,
//           'name': nameController.text.trim(),
//           'email': emailController.text.trim(),
//           'phone': phoneController.text.trim(),
//           'role': 'customer',
//           'createdAt': FieldValue.serverTimestamp(),
//         });
//       }

//       Get.offAll(() => const ShellView());
//     } on FirebaseAuthException catch (e) {
//       _error(_firebaseError(e.code));
//     } catch (e) {
//       _error('Account created, but profile setup failed.');
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   // =========================
//   // FORGOT PASSWORD
//   // =========================
//   Future<void> resetPassword(String email) async {
//     if (email.trim().isEmpty) {
//       _error('Please enter your email');
//       return;
//     }

//     try {
//       isLoading.value = true;

//       await _auth.sendPasswordResetEmail(email: email.trim());

//       Get.back();

//       toast('Password reset link sent to your email');
//     } on FirebaseAuthException catch (e) {
//       _error(_firebaseError(e.code));
//     } catch (e) {
//       _error('Could not send reset email');
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   // =========================
//   // FIREBASE ERROR MESSAGES
//   // =========================
//   String _firebaseError(String code) {
//     switch (code) {
//       case 'invalid-email':
//         return 'Please enter a valid email address';

//       case 'user-not-found':
//         return 'No account found with this email';

//       case 'wrong-password':
//       case 'invalid-credential':
//         return 'Incorrect email or password';

//       case 'email-already-in-use':
//         return 'An account already exists with this email';

//       case 'weak-password':
//         return 'Password is too weak';

//       case 'network-request-failed':
//         return 'Please check your internet connection';

//       case 'too-many-requests':
//         return 'Too many attempts. Please try again later';

//       case 'user-disabled':
//         return 'This account has been disabled';

//       default:
//         return 'Authentication failed. Please try again';
//     }
//   }

//   void _error(String message) {
//     Get.snackbar(
//       'Error',
//       message,
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: Colors.red.shade700,
//       colorText: Colors.white,
//       margin: const EdgeInsets.all(16),
//     );
//   }

//   @override
//   void onClose() {
//     emailController.dispose();
//     passwordController.dispose();
//     nameController.dispose();
//     phoneController.dispose();
//     super.onClose();
//   }
// }

// class LoginView extends StatelessWidget {
//   LoginView({super.key});

//   final AuthController controller = Get.put(AuthController());

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: C.ink,
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(24),
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 440),
//               child: Obx(
//                 () => Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // =========================
//                     // LOGO
//                     // =========================
//                     Row(
//                       children: [
//                         Container(
//                           width: 48,
//                           height: 48,
//                           decoration: BoxDecoration(
//                             color: C.orange,
//                             borderRadius: BorderRadius.circular(14),
//                           ),
//                           child: const Icon(Icons.handyman, color: C.ink),
//                         ),
//                         const SizedBox(width: 12),
//                         const Text(
//                           'Twins Handyman llc',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w800,
//                             fontSize: 22,
//                           ),
//                         ),
//                       ],
//                     ),

//                     gap(32),

//                     // =========================
//                     // TITLE
//                     // =========================
//                     Text(
//                       controller.signUp.value
//                           ? 'Create your account'
//                           : 'Welcome back',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w800,
//                         fontSize: 28,
//                       ),
//                     ),

//                     gap(6),

//                     const Text(
//                       'North Jersey & Staten Island',
//                       style: TextStyle(color: Color(0xFFB9BFC6)),
//                     ),

//                     gap(24),

//                     // =========================
//                     // FORM
//                     // =========================
//                     Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(18),
//                       ),
//                       child: Column(
//                         children: [
//                           // NAME
//                           if (controller.signUp.value) ...[
//                             _field(
//                               controller.nameController,
//                               'Full name',
//                               Icons.person_outline,
//                             ),
//                             gap(),
//                           ],

//                           // EMAIL
//                           _field(
//                             controller.emailController,
//                             'Email',
//                             Icons.mail_outline,
//                             keyboardType: TextInputType.emailAddress,
//                           ),

//                           gap(),

//                           // PHONE
//                           if (controller.signUp.value) ...[
//                             _field(
//                               controller.phoneController,
//                               'Phone',
//                               Icons.call_outlined,
//                               keyboardType: TextInputType.phone,
//                             ),
//                             gap(),
//                           ],

//                           // PASSWORD
//                           _passwordField(),

//                           gap(16),

//                           // =========================
//                           // LOGIN / SIGNUP BUTTON
//                           // =========================
//                           SizedBox(
//                             width: double.infinity,
//                             child: ElevatedButton(
//                               onPressed: controller.isLoading.value
//                                   ? null
//                                   : () {
//                                       if (controller.signUp.value) {
//                                         controller.createAccount();
//                                       } else {
//                                         controller.login();
//                                       }
//                                     },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: C.orange,
//                                 foregroundColor: C.ink,
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 16,
//                                 ),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                               child: controller.isLoading.value
//                                   ? const SizedBox(
//                                       height: 22,
//                                       width: 22,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                       ),
//                                     )
//                                   : Text(
//                                       controller.signUp.value
//                                           ? 'Create account'
//                                           : 'Log in',
//                                       style: const TextStyle(
//                                         fontWeight: FontWeight.w800,
//                                       ),
//                                     ),
//                             ),
//                           ),

//                           gap(10),

//                           // =========================
//                           // SOCIAL BUTTONS
//                           // =========================
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: OutlinedButton.icon(
//                                   onPressed: () {
//                                     Get.snackbar(
//                                       'Coming soon',
//                                       'Apple Sign-In will be connected next.',
//                                     );
//                                   },
//                                   icon: const Icon(Icons.apple),
//                                   label: const Text('Apple'),
//                                 ),
//                               ),
//                               const SizedBox(width: 10),
//                               Expanded(
//                                 child: OutlinedButton.icon(
//                                   onPressed: () {
//                                     Get.snackbar(
//                                       'Coming soon',
//                                       'Google Sign-In will be connected next.',
//                                     );
//                                   },
//                                   icon: const Icon(
//                                     Icons.g_mobiledata,
//                                     size: 28,
//                                   ),
//                                   label: const Text('Google'),
//                                 ),
//                               ),
//                             ],
//                           ),

//                           // =========================
//                           // FORGOT PASSWORD
//                           // =========================
//                           if (!controller.signUp.value)
//                             TextButton(
//                               onPressed: controller.isLoading.value
//                                   ? null
//                                   : () => _forgotPassword(),
//                               child: const Text(
//                                 'Forgot password?',
//                                 style: TextStyle(color: C.soft),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),

//                     gap(8),

//                     // =========================
//                     // SWITCH LOGIN / SIGNUP
//                     // =========================
//                     Center(
//                       child: TextButton(
//                         onPressed: controller.isLoading.value
//                             ? null
//                             : () {
//                                 controller.signUp.toggle();
//                               },
//                         child: Text(
//                           controller.signUp.value
//                               ? 'Have an account? Log in'
//                               : 'New here? Sign up',
//                           style: const TextStyle(
//                             color: C.orange,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // =========================
//   // TEXT FIELD
//   // =========================
//   Widget _field(
//     TextEditingController textController,
//     String label,
//     IconData icon, {
//     TextInputType? keyboardType,
//   }) {
//     return TextField(
//       controller: textController,
//       keyboardType: keyboardType,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon, size: 20),
//       ),
//     );
//   }

//   // =========================
//   // PASSWORD FIELD
//   // =========================
//   Widget _passwordField() {
//     return TextField(
//       controller: controller.passwordController,
//       obscureText: controller.obscurePassword.value,
//       decoration: InputDecoration(
//         labelText: 'Password',
//         prefixIcon: const Icon(Icons.lock_outline, size: 20),
//         suffixIcon: IconButton(
//           onPressed: () {
//             controller.obscurePassword.toggle();
//           },
//           icon: Icon(
//             controller.obscurePassword.value
//                 ? Icons.visibility_off
//                 : Icons.visibility,
//           ),
//         ),
//       ),
//     );
//   }

//   // =========================
//   // FORGOT PASSWORD DIALOG
//   // =========================
//   void _forgotPassword() {
//     final emailController = TextEditingController(
//       text: controller.emailController.text,
//     );

//     Get.defaultDialog(
//       title: 'Reset password',
//       content: Padding(
//         padding: const EdgeInsets.all(8),
//         child: TextField(
//           controller: emailController,
//           keyboardType: TextInputType.emailAddress,
//           decoration: const InputDecoration(
//             labelText: 'Email',
//             prefixIcon: Icon(Icons.mail_outline),
//           ),
//         ),
//       ),
//       textConfirm: 'Send link',
//       confirmTextColor: Colors.white,
//       buttonColor: C.orange,
//       textCancel: 'Cancel',
//       onConfirm: () {
//         controller.resetPassword(emailController.text);
//       },
//     );
//   }
// }
