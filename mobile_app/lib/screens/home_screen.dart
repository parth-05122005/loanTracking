import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'upload_receipt_screen.dart';
import 'create_loan_screen.dart';
import 'profile_screen.dart';
import 'monthly_summary_screen.dart'; // <--- Ensure this is imported

class HomeScreen extends StatelessWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid}); 

  // --- DELETE FUNCTION ---
  Future<void> _deleteTransaction(BuildContext context, String txId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction?"),
        content: const Text("This action cannot be undone. Your balance will be updated."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text("Cancel", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('transactions').doc(txId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaction deleted"), 
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;
    Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: _buildAppBar(context, isDarkMode),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('loans')
            .where('beneficiary_uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, loanSnapshot) {
          if (loanSnapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          
          if (!loanSnapshot.hasData || loanSnapshot.data!.docs.isEmpty) {
            return _buildNoLoanView(context);
          }

          var loanDoc = loanSnapshot.data!.docs.first;
          var loanData = loanDoc.data() as Map<String, dynamic>;
          String loanId = loanDoc.id;
          
          double sanctionedAmount = double.tryParse(loanData['sanctioned_amount']?.toString() ?? '0') ?? 0.0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('loan_id', isEqualTo: loanId)
                .snapshots(),
            builder: (context, txSnapshot) {
              if (txSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              double totalUtilized = 0.0;
              List<QueryDocumentSnapshot> sortedDocs = [];

              if (txSnapshot.hasData) {
                sortedDocs = txSnapshot.data!.docs;
                sortedDocs.sort((a, b) {
                  Timestamp tA = (a.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
                  Timestamp tB = (b.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
                  return tB.compareTo(tA);
                });

                for (var doc in sortedDocs) {
                  var data = doc.data() as Map<String, dynamic>;
                  totalUtilized += double.tryParse(data['amount'].toString()) ?? 0.0;
                }
              }

              double currentBalance = (sanctionedAmount - totalUtilized).clamp(0.0, double.infinity);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(sanctionedAmount, totalUtilized, currentBalance),
                    
                    const SizedBox(height: 25),
                    
                    // --- ROW WITH TITLE AND BUTTON ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Recent Transactions", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        
                        TextButton(
                          onPressed: () {
                             Navigator.push(context, MaterialPageRoute(
                               builder: (_) => MonthlySummaryScreen(loanId: loanId)
                             ));
                          },
                          child: const Text("View Monthly", style: TextStyle(color: Colors.blue)),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    
                    _buildTransactionList(context, sortedDocs, cardColor, textColor),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FirebaseFirestore.instance
            .collection('loans')
            .where('beneficiary_uid', isEqualTo: uid)
            .get()
            .then((snap) {
              if (snap.docs.isNotEmpty) {
                 Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UploadReceiptScreen(loanId: snap.docs.first.id)
                ));
              }
            });
        },
        label: const Text("New Expense"),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDarkMode) {
    return AppBar(
      backgroundColor: Colors.transparent, 
      elevation: 0,
      title: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          String userName = "Beneficiary"; 
          if (snapshot.hasData && snapshot.data!.exists) {
            userName = snapshot.data!.get('name') ?? "Beneficiary";
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome Back,", style: TextStyle(fontSize: 14, color: Colors.grey)),
              Text(userName, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)), 
            ],
          );
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)));
            },
            child: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.person, color: Colors.green.shade800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoLoanView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.green.shade200),
            const SizedBox(height: 20),
            const Text("No Active Loan Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("It looks like you haven't set up your loan details yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double sanctioned, double utilized, double balance) {
    double percent = 0.0;
    if (sanctioned > 0) {
      percent = (utilized / sanctioned).clamp(0.0, 1.0);
    }

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade900, Colors.green.shade600, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.1, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))
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

  Widget _getCategoryIcon(String category) {
    category = category.toLowerCase();
    IconData icon;
    Color color;

    if (category.contains('food') || category.contains('eat')) {
      icon = Icons.restaurant;
      color = Colors.orange;
    } else if (category.contains('travel') || category.contains('fuel') || category.contains('transport')) {
      icon = Icons.local_gas_station;
      color = Colors.blue;
    } else if (category.contains('tool') || category.contains('equipment') || category.contains('repair')) {
      icon = Icons.build;
      color = Colors.grey.shade700;
    } else if (category.contains('seed') || category.contains('farm') || category.contains('fert')) {
      icon = Icons.eco;
      color = Colors.green;
    } else if (category.contains('labor') || category.contains('wage')) {
      icon = Icons.group;
      color = Colors.purple;
    } else {
      icon = Icons.receipt_long;
      color = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildTransactionList(BuildContext context, List<QueryDocumentSnapshot> docs, Color cardColor, Color textColor) {
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        var tx = docs[index].data() as Map<String, dynamic>;
        String txId = docs[index].id; 
        
        String vendor = tx['vendor_name'] ?? 'Unknown Vendor';
        String category = tx['category'] ?? 'General';
        double amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
        String? receiptUrl = tx['receipt_url'];
        
        String dateString = "Pending";
        if (tx['timestamp'] != null) {
          try {
            Timestamp t = tx['timestamp'];
            dateString = DateFormat('dd MMM').format(t.toDate());
          } catch (e) {
            dateString = "Error";
          }
        }

        return Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: () => _deleteTransaction(context, txId),
            onTap: () {
              if (receiptUrl != null && receiptUrl.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                  body: Center(
                    child: Hero(
                      tag: receiptUrl,
                      child: Image.network(receiptUrl),
                    ),
                  ),
                )));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No receipt image attached")));
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _getCategoryIcon(category),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 4),
                        Text(category, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("- ₹${amount.toStringAsFixed(0)}", 
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(dateString, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}