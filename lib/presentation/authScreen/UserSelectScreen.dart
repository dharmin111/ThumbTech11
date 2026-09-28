// import 'package:flutter/material.dart';
// import 'package:thumstechs/presentation/authScreen/LoginScreen.dart';
//
// class UserSelectionScreen extends StatefulWidget {
//   const UserSelectionScreen({super.key});
//
//   @override
//   State<UserSelectionScreen> createState() => _UserSelectionScreenState();
// }
//
// class _UserSelectionScreenState extends State<UserSelectionScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 80),
//
//               /// IMAGE
//               SizedBox(
//                 height: 350,
//                 width: double.infinity,
//                 child: Image.asset(
//                   'assets/images/img_2.png',
//                   fit: BoxFit.contain,
//                 ),
//               ),
//
//               const SizedBox(height: 40),
//
//               /// CUSTOMER BUTTON
//               GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const LoginScreen()),
//                   );
//                 },
//                 child: Container(
//                   width: double.infinity,
//                   height: 90,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 20,
//                   ),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(18),
//                     gradient: const LinearGradient(
//                       colors: [
//                         Color(0xFF2F2FE4),
//                         Color(0xFF4B1EFF),
//                       ],
//                     ),
//                   ),
//                   child: const Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             Text(
//                               "I Want Service",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               "(I am a Customer)",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 15,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Icon(Icons.arrow_forward, color: Colors.white, size: 32),
//                     ],
//                   ),
//                 ),
//               ),
//
//               const SizedBox(height: 16),
//
//               /// TECHNICIAN BUTTON
//               GestureDetector(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const LoginScreen()),
//                   );
//                 },
//                 child: Container(
//                   width: double.infinity,
//                   height: 90,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 24,
//                     vertical: 22,
//                   ),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(18),
//                     gradient: const LinearGradient(
//                       colors: [
//                         Color(0xFF2F2FE4),
//                         Color(0xFF4B1EFF),
//                       ],
//                     ),
//                   ),
//                   child: const Row(
//                     children: [
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             Text(
//                               "I Want Work",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               "(I am a Technician)",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 15,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Icon(Icons.arrow_forward, color: Colors.white, size: 32),
//                     ],
//                   ),
//                 ),
//               ),
//
//               const Spacer(),
//               Row(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Text("Already have an account "),
//                   ),
//                   SizedBox(width: 20,),
//                   TextButton(onPressed: () => Navigator.push(context,
//                       MaterialPageRoute(builder: (context) =>
//                           LoginScreen(),)), child: Text("Login",style: TextStyle(fontSize: 15),))
//                 ],
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }