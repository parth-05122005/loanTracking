import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageHelper {
  static final ImagePicker _picker = ImagePicker();

  // This is the function your screen is looking for
  static Future<File?> pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, // Opens Camera
        imageQuality: 80, // Reduces size slightly for faster upload
      );
      
      if (photo != null) {
        return File(photo.path);
      }
      return null;
    } catch (e) {
      print("Error picking image: $e");
      return null;
    }
  }
}