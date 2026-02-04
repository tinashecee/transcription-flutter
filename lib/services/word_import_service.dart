import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

class WordImportService {
  final Dio _dio;

  WordImportService({
    required Dio dio,
  })  : _dio = dio;

  /// Import Word document and convert to HTML via Flask API
  /// Returns null if user cancels the file picker
  Future<String?> importWordToHtml({
    required BuildContext context,
  }) async {
    try {
      // Open file picker
      final XFile? file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Word Documents',
            extensions: ['docx', 'doc'],
          ),
        ],
      );

      if (file == null) {
        // User cancelled file picker - return null instead of throwing
        return null;
      }

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Importing Word document...'),
              ],
            ),
          ),
        );
      }

      // Read file as bytes
      final fileBytes = await file.readAsBytes();

      // Create multipart form data
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: file.name,
        ),
      });

      // Send file to server for conversion
      // Note: Authentication is handled by Dio interceptors in ApiClient
      final response = await _dio.post(
        '/convert/docx-to-html',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200 && response.data != null) {
        final htmlContent = response.data['html_content'] as String?;
        if (htmlContent == null || htmlContent.isEmpty) {
          throw Exception('Server returned empty HTML content');
        }
        return htmlContent;
      } else {
        throw Exception('Conversion failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      final errorMessage = e.response?.data?['error']?.toString() ?? 
                          e.response?.data?.toString() ?? 
                          e.message ?? 
                          'Unknown error';
      throw Exception('Import failed: $errorMessage');
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // Dialog might not be open, ignore
        }
      }
      
      // Wrap in exception
      throw Exception('Import failed: ${e.toString()}');
    }
  }
}
