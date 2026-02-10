import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../theme_provider.dart'; // <--- IMPORT THE NEW FILE
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Profile"),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
          FirebaseFirestore.instance.collection('loans').where('beneficiary_uid', isEqualTo: uid).get(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
             return const Center(child: Text("Error loading profile"));
          }

          var userDoc = snapshot.data![0] as DocumentSnapshot;
          String name = userDoc.get('name') ?? 'User';
          String email = userDoc.get('email') ?? 'No Email';

          var loanQuery = snapshot.data![1] as QuerySnapshot;
          double sanctionedAmount = 0.0;
          if (loanQuery.docs.isNotEmpty) {
             sanctionedAmount = double.tryParse(loanQuery.docs.first.get('sanctioned_amount').toString()) ?? 0.0;
          }
          
          final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50, 
                  backgroundColor: Colors.green.shade200, 
                  child: Icon(Icons.person, size: 60, color: Colors.green.shade900)
                ),
                const SizedBox(height: 20),
                Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                Text(email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                         const Row(children: [Icon(Icons.monetization_on, color: Colors.green), SizedBox(width: 10), Text("Loan Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                         const Divider(height: 30),
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Sanctioned Amount", style: TextStyle(color: Colors.grey, fontSize: 16)),
                            Text(currency.format(sanctionedAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Appearance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                const SizedBox(height: 10),
                
                // --- SWITCH THAT UPDATES THE PROVIDER ---
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (_, mode, __) {
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        title: const Text("Night Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                        secondary: Icon(Icons.dark_mode, color: isDarkMode ? Colors.white : Colors.black),
                        value: mode == ThemeMode.dark,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      try { await GoogleSignIn().signOut(); } catch (_) {}
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}