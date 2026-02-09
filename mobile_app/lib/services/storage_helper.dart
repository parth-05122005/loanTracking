// lib/services/storage_helper.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageHelper {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadReceipt(String filePath, String loanId) async {
    File file = File(filePath);
    
    try {
      // Create a unique filename: loans/{loanId}/{timestamp}.jpg
      String fileName = 'loans/$loanId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Create a reference to the location in Firebase Storage
      Reference ref = _storage.ref().child(fileName);
      
      // Upload the file
      UploadTask uploadTask = ref.putFile(file);
      
      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;
      
      // Get the download URL to save in your PostgreSQL database later
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
      
    } catch (e) {
      print("Error uploading receipt: $e");
      return null;
    }
  }
}