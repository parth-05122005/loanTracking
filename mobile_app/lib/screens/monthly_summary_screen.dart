import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MonthlySummaryScreen extends StatelessWidget {
  final String loanId;

  const MonthlySummaryScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;
    Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Monthly Spending", style: TextStyle(color: textColor)),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('loan_id', isEqualTo: loanId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No transactions found", style: TextStyle(color: textColor)));
          }

          // --- LOGIC: Group Expenses by Month ---
          Map<String, double> monthlyTotals = {};
          
          // We need a separate list to keep months in correct order (Newest first)
          List<String> sortedMonths = [];

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            double amount = double.tryParse(data['amount'].toString()) ?? 0.0;
            Timestamp? t = data['timestamp'];
            
            if (t != null) {
              DateTime date = t.toDate();
              String key = DateFormat('MMMM yyyy').format(date); // e.g., "February 2026"
              
              if (!monthlyTotals.containsKey(key)) {
                monthlyTotals[key] = 0.0;
                // Add to list only if not already there (simple sort by insertion order of stream)
                // Note: For perfect sorting, we'd sort the list afterwards based on Date parsing.
                // Firebase usually returns sorted if we query with orderBy, but let's assume random order fix:
                if (!sortedMonths.contains(key)) sortedMonths.add(key);
              }
              monthlyTotals[key] = monthlyTotals[key]! + amount;
            }
          }
          
          // Simple sort: Recent months usually come first if data is recent. 
          // For strict sorting, we can rely on the fact that we iterate through them.

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: sortedMonths.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 15),
            itemBuilder: (ctx, index) {
              String month = sortedMonths[index];
              double total = monthlyTotals[month]!;
              final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

              return Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month, color: Colors.blue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Spent", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          Text(month, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        currency.format(total),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}