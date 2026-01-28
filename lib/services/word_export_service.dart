import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

class WordExportService {
  final Dio _dio;

  WordExportService({
    required Dio dio,
  })  : _dio = dio;

  /// Export HTML content to Word document via Flask API
  Future<void> exportHtmlToWord({
    required BuildContext context,
    required String htmlContent,
    required String fileName,
    required Map<String, dynamic> metadata,
  }) async {
    try {
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
                Text('Creating Word document...'),
              ],
            ),
          ),
        );
      }

      // Send HTML to server for conversion
      // Note: Authentication is handled by Dio interceptors in ApiClient
      final response = await _dio.post(
        '/convert/html-to-docx',
        data: {
          'html_content': htmlContent,
          'metadata': metadata,
          'filename': fileName,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200 && response.data != null) {
        // Save the DOCX file
        await _saveDocxFile(
          context: context,
          bytes: response.data as List<int>,
          fileName: fileName,
        );
      } else {
        throw Exception('Conversion failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      final errorMessage = e.response?.data?.toString() ?? e.message ?? 'Unknown error';
      throw Exception('Export failed: $errorMessage');
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      rethrow;
    }
  }

  Future<void> _saveDocxFile({
    required BuildContext context,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      // Ensure filename has .docx extension
      final sanitizedFileName = fileName.endsWith('.docx')
          ? fileName
          : '$fileName.docx';

      // Open save dialog
      final location = await getSaveLocation(
        suggestedName: sanitizedFileName,
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Word Document',
            extensions: ['docx'],
          ),
        ],
      );

      if (location == null) {
        // User cancelled
        return;
      }

      // Ensure the path has .docx extension
      var filePath = location.path;
      if (!filePath.toLowerCase().endsWith('.docx')) {
        filePath = '$filePath.docx';
      }

      // Write file
      await File(filePath).writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcript exported to ${File(filePath).path}'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
      rethrow;
    }
  }
}
