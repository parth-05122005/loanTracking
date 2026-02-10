import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; // IMPORT THIS
import '../services/storage_helper.dart'; 
import '../services/cloudinary_service.dart'; 
import 'dart:io';

class UploadReceiptScreen extends StatefulWidget {
  final String loanId;
  const UploadReceiptScreen({super.key, required this.loanId});

  @override
  State<UploadReceiptScreen> createState() => _UploadReceiptScreenState();
}

class _UploadReceiptScreenState extends State<UploadReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  File? _imageFile;
  bool _isUploading = false;
  String _statusMessage = "Save Expense"; // To show "Getting Location..."

  Future<void> _pickImage() async {
    File? img = await StorageHelper.pickImage();
    if (img != null) {
      setState(() => _imageFile = img);
    }
  }

  // --- NEW: FUNCTION TO GET LOCATION ---
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null; // Location services are disabled

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please attach a receipt photo")));
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = "Fetching Location..."; // Give user feedback
    });

    try {
      double newAmount = double.parse(_amountController.text.replaceAll(',', ''));

      // 1. Check Balance (Safety Feature)
      var loanDoc = await FirebaseFirestore.instance.collection('loans').doc(widget.loanId).get();
      var loanData = loanDoc.data() as Map<String, dynamic>;
      double sanctioned = double.tryParse(loanData['sanctioned_amount'].toString()) ?? 0.0;
      
      var txQuery = await FirebaseFirestore.instance.collection('transactions').where('loan_id', isEqualTo: widget.loanId).get();
      double totalUsed = 0.0;
      for (var doc in txQuery.docs) {
        totalUsed += double.tryParse(doc['amount'].toString()) ?? 0.0;
      }

      double availableBalance = sanctioned - totalUsed;

      if (newAmount > availableBalance) {
        _showErrorDialog(availableBalance, newAmount);
        setState(() { _isUploading = false; _statusMessage = "Save Expense"; });
        return; 
      }

      // 2. Upload Image
      setState(() => _statusMessage = "Uploading Image...");
      String? imageUrl = await CloudinaryService.uploadImage(_imageFile!);
      
      // 3. Get Location (NEW STEP)
      setState(() => _statusMessage = "Tagging Location...");
      Position? position = await _getCurrentLocation();

      if (imageUrl != null) {
        // 4. Save to Firestore with ALL FIELDS
        await FirebaseFirestore.instance.collection('transactions').add({
          'loan_id': widget.loanId,
          'amount': newAmount,
          'vendor_name': _vendorController.text,
          'category': _categoryController.text,
          'receipt_url': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending', // Default status
          
          // --- SAVING EXACTLY AS YOUR DB IMAGE SHOWS ---
          'geo_location': {
            'lat': position?.latitude ?? 0.0, // Default to 0.0 if fetch fails
            'lng': position?.longitude ?? 0.0,
          }
        });
        
        if (mounted) Navigator.pop(context); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() { _isUploading = false; _statusMessage = "Save Expense"; });
    }
  }

  void _showErrorDialog(double available, double attempted) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Insufficient Balance", style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("You cannot exceed your sanctioned loan limit."),
            const SizedBox(height: 15),
            Text("Available: ${currency.format(available)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            Text("Attempted: ${currency.format(attempted)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                    image: _imageFile != null 
                      ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : null
                  ),
                  child: _imageFile == null 
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text("Tap to attach receipt")],
                      )
                    : null,
                ),
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _vendorController,
                decoration: const InputDecoration(labelText: "Vendor Name", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount (₹)", border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (double.tryParse(v) == null) return "Invalid Number";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitExpense,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  child: _isUploading 
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 15),
                          Text(_statusMessage, style: const TextStyle(fontSize: 16, color: Colors.white)),
                        ],
                      )
                    : Text(_statusMessage, style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}