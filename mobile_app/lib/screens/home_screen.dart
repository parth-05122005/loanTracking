import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Optional: for Google Sign Out
import 'upload_receipt_screen.dart';
import 'login_screen.dart';
import 'create_loan_screen.dart'; 

class HomeScreen extends StatelessWidget {
  final String uid;

  const HomeScreen({super.key, required this.uid}); 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      // 1. First Stream: Get the Loan Details (Limit, ID)
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('loans')
            .where('beneficiary_uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, loanSnapshot) {
          if (loanSnapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          
          // --- THE FIX: Handle "No Loan Found" Gracefully ---
          if (!loanSnapshot.hasData || loanSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.green.shade200),
                    const SizedBox(height: 20),
                    const Text(
                      "No Active Loan Profile", 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "It looks like you haven't set up your loan details yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (_) => const CreateLoanScreen()
                        ));
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Setup Loan Profile"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("User ID: ${uid.substring(0, 6)}...", style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                  ],
                ),
              ),
            );
          }

          // Loan Found! Proceed to show Dashboard
          var loanDoc = loanSnapshot.data!.docs.first;
          var loanData = loanDoc.data() as Map<String, dynamic>;
          String loanId = loanDoc.id;
          
          // Safe Parsing of Sanctioned Amount
          double sanctionedAmount = 0.0;
          if (loanData['sanctioned_amount'] != null) {
            sanctionedAmount = double.tryParse(loanData['sanctioned_amount'].toString()) ?? 0.0;
          }

          // 2. Second Stream: Get ALL Transactions for this loan
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('loan_id', isEqualTo: loanId)
                // .orderBy('timestamp', descending: true) // Keep commented if Index error persists
                .snapshots(),
            builder: (context, txSnapshot) {
              if (txSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 3. CALCULATE THE LIVE BALANCE
              double totalUtilized = 0.0;
              List<QueryDocumentSnapshot> sortedDocs = [];

              if (txSnapshot.hasData) {
                sortedDocs = txSnapshot.data!.docs;
                
                // Manual Sort (Fixes the "Index" crash if you haven't created one in Firebase)
                sortedDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  Timestamp tA = dataA['timestamp'] ?? Timestamp.now();
                  Timestamp tB = dataB['timestamp'] ?? Timestamp.now();
                  return tB.compareTo(tA); // Newest first
                });

                // Calculate Sum
                for (var doc in sortedDocs) {
                  var data = doc.data() as Map<String, dynamic>;
                  double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
                  totalUtilized += amount;
                }
              }

              double currentBalance = sanctionedAmount - totalUtilized;
              
              // Prevent negative balance display
              if (currentBalance < 0) currentBalance = 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pass calculated values to the card
                    _buildBalanceCard(sanctionedAmount, totalUtilized, currentBalance),
                    
                    const SizedBox(height: 25),
                    const Text("Recent Transactions", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    
                    // Pass the sorted list directly
                    _buildTransactionList(sortedDocs),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Use the loan ID we found to open upload screen
          FirebaseFirestore.instance
            .collection('loans')
            .where('beneficiary_uid', isEqualTo: uid)
            .get()
            .then((snap) {
              if (snap.docs.isNotEmpty) {
                 Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UploadReceiptScreen(loanId: snap.docs.first.id)
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please set up your loan profile first."))
                );
              }
            });
        },
        label: const Text("New Expense"),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome Back,", style: TextStyle(fontSize: 14, color: Colors.grey)),
          Text("Beneficiary", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent), 
          onPressed: () async {
            // 1. Sign out from Firebase
            await FirebaseAuth.instance.signOut();
            
            // 2. Sign out from Google (Clears cached account selection)
            try {
              await GoogleSignIn().signOut();
            } catch (e) {
              // Ignore if Google Sign In wasn't used
            }

            // 3. FORCE Navigation back to Login (Clear the stack)
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false, // This removes all previous routes
              );
            }
          }
        ),
      ],
    );
  }

  Widget _buildBalanceCard(double sanctioned, double utilized, double balance) {
    double percent = 0.0;
    if (sanctioned > 0) {
      percent = utilized / sanctioned;
      if (percent > 1.0) percent = 1.0; // Cap at 100%
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Available Balance", 
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(currency.format(balance),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              CircularPercentIndicator(
                radius: 35.0,
                lineWidth: 8.0,
                percent: percent,
                center: Text("${(percent * 100).toInt()}%", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                footer: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text("Used", style: TextStyle(color: Colors.white70, fontSize: 10)),
                ),
                progressColor: Colors.white,
                backgroundColor: Colors.white24,
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn("Sanctioned", currency.format(sanctioned)),
              _buildStatColumn("Utilized", currency.format(utilized)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }

  Widget _buildTransactionList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text("No transactions yet. Add your first expense!", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        var tx = docs[index].data() as Map<String, dynamic>;
        
        // SAFE PARSING
        String vendor = tx['vendor_name'] ?? 'Unknown Vendor';
        double amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
        
        String dateString = "Pending";
        if (tx['timestamp'] != null) {
          try {
            Timestamp t = tx['timestamp'];
            dateString = DateFormat('dd MMM yyyy').format(t.toDate());
          } catch (e) {
            dateString = "Date Error";
          }
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
            ),
            title: Text(vendor, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(dateString),
            trailing: Text("- ₹${amount.toStringAsFixed(0)}", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        );
      },
    );
  }
}