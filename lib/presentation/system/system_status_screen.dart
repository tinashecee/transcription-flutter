import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/update_manager.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  bool _checking = false;
  Map<String, dynamic>? _downloadProgress;

  @override
  void initState() {
    super.initState();
    
    // Listen to download progress
    UpdateManager.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    });

    // Auto-check for updates when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isWindows) {
        _checkForUpdates();
      }
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
    });

    await UpdateManager.checkForUpdatesManual(context);

    if (mounted) {
      setState(() {
        _checking = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'System Status',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF115343),
              ),
            ),
          ),
            // App Version Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFF115343),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'App Information',
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF115343),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow('App Name', 'Testimony Transcriber'),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Current Version',
                    UpdateManager.appDisplayVersion ?? 'Unknown',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Platform', Platform.operatingSystem),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Update Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.system_update,
                        color: const Color(0xFF115343),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Updates',
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF115343),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (!Platform.isWindows)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Automatic updates are only available on Windows',
                              style: GoogleFonts.roboto(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: _checking ? null : _checkForUpdates,
                      icon: _checking
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_checking ? 'Checking...' : 'Check for Updates'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF115343),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    
                    if (_downloadProgress != null) ...[
                      const SizedBox(height: 20),
                      _buildDownloadProgress(),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.roboto(
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadProgress() {
    final status = _downloadProgress!['status'] as String;
    final progress = _downloadProgress!['progress'] as double?;
    final received = _downloadProgress!['received'] as int?;
    final total = _downloadProgress!['total'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status == 'downloading')
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade700,
                  ),
                )
              else if (status == 'downloaded')
                Icon(Icons.check_circle, color: Colors.green.shade700)
              else if (status == 'failed')
                Icon(Icons.error, color: Colors.red.shade700)
              else
                Icon(Icons.downloading, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status == 'downloading'
                      ? 'Downloading update...'
                      : status == 'downloaded'
                          ? 'Download complete!'
                          : status == 'failed'
                              ? 'Download failed'
                              : 'Starting download...',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w600,
                    color: status == 'failed' ? Colors.red.shade900 : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null && progress > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 8),
            if (received != null)
              Text(
                total != null
                    ? '${_formatBytes(received)} / ${_formatBytes(total)} (${(progress * 100).toStringAsFixed(1)}%)'
                    : _formatBytes(received),
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
          if (status == 'failed' && _downloadProgress!['error'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: ${_downloadProgress!['error']}',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.red.shade900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
