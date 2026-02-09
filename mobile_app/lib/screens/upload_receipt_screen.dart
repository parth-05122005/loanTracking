import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // <--- REMOVE THIS
import '../services/cloudinary_service.dart'; // <--- ADD THIS

class UploadReceiptScreen extends StatefulWidget {
  final String loanId;
  const UploadReceiptScreen({super.key, required this.loanId});

  @override
  State<UploadReceiptScreen> createState() => _UploadReceiptScreenState();
}

class _UploadReceiptScreenState extends State<UploadReceiptScreen> {
  File? _imageFile;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  bool _isUploading = false;
  
  // Initialize the new service
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

Future<void> _submitTransaction() async {
    print("🚀 STARTING SUBMIT..."); // Debug Print 1

    if (!_formKey.currentState!.validate() || _imageFile == null) {
      print("❌ Form validation failed or no image selected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please attach a receipt and fill details"))
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      print("📸 Uploading image to Cloudinary..."); // Debug Print 2
      String? imageUrl = await _cloudinaryService.uploadImage(_imageFile!);
      
      if (imageUrl == null) {
        print("❌ Cloudinary returned NULL. Upload failed.");
        throw Exception("Image upload failed");
      }
      print("✅ Image Uploaded! URL: $imageUrl"); // Debug Print 3

      print("💾 Saving to Firestore..."); // Debug Print 4
      await FirebaseFirestore.instance.collection('transactions').add({
        "loan_id": widget.loanId,
        "amount": double.parse(_amountController.text),
        "vendor_name": _vendorController.text,
        "category": "materials",
        "receipt_url": imageUrl,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "pending_verification",
        "geo_location": {"lat": 12.91, "lng": 79.13} 
      });
      print("✅ Firestore Write Successful!"); // Debug Print 5

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense Submitted Successfully!"))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print("🛑 CRITICAL ERROR: $e"); // Debug Print 6
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... The rest of your UI code remains exactly the same ...
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Receipt")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                            Text("Tap to take photo of receipt"),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _vendorController,
                decoration: const InputDecoration(
                  labelText: "Vendor Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Total Amount",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT EXPENSE", style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}