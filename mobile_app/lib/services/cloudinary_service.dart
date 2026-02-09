import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // REPLACE WITH YOUR VALUES
  final String cloudName = "db4exuwwb"; 
  final String uploadPreset = "loan_app_upload"; // The unsigned preset name

  Future<String?> uploadImage(File imageFile) async {
    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      
      var request = http.MultipartRequest("POST", uri);
      
      // 1. Add the file
      var multipartFile = await http.MultipartFile.fromPath(
        'file', 
        imageFile.path
      );
      request.files.add(multipartFile);

      // 2. Add the upload preset (Security key)
      request.fields['upload_preset'] = uploadPreset;

      // 3. Send Request
      var response = await request.send();

      // 4. Get Response
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonMap = jsonDecode(responseString);
        
        // Return the secure URL of the uploaded image
        return jsonMap['secure_url'];
      } else {
        print("Upload Failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error uploading to Cloudinary: $e");
      return null;
    }
  }
}