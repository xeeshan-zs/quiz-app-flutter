import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

class CloudinaryService {
  // Replace these with your actual Cloudinary credentials
  final String _cloudName = AppConfig.cloudinaryCloudName; 
  final String _uploadPreset = AppConfig.cloudinaryUploadPreset;

  /// Uploads an image file to Cloudinary and returns the secure URL
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset;

      // Determine if web or mobile to handle file adding correctly
      // XFile abstraction usually handles this, but readAsBytes is safest for web/mobile compatibility
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        bytes, 
        filename: imageFile.name
      ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'];
      } else {
        print('Cloudinary Upload Failed: ${response.statusCode}');
        // Try to read error body
        final responseData = await response.stream.toBytes();
        print('Error Body: ${String.fromCharCodes(responseData)}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }
}
