import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/ringtone_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

/// Ringtone Settings Screen
/// Allows users to download, select, and manage custom ringtones
class RingtoneSettingsScreen extends StatefulWidget {
  const RingtoneSettingsScreen({super.key});

  @override
  State<RingtoneSettingsScreen> createState() => _RingtoneSettingsScreenState();
}

class _RingtoneSettingsScreenState extends State<RingtoneSettingsScreen> {
  final _ringtoneService = RingtoneService();
  final _urlController = TextEditingController();
  String? _currentRingtoneName;
  String? _currentRingtonePath;
  List<FileSystemEntity> _availableRingtones = [];
  bool _isLoading = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRingtone();
    _loadAvailableRingtones();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRingtone() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final name = await _ringtoneService.getCurrentRingtoneName();
      final path = await _ringtoneService.getCurrentRingtonePath();
      
      setState(() {
        _currentRingtoneName = name ?? 'Default';
        _currentRingtonePath = path;
      });
    } catch (e) {
      Log.e('Error loading current ringtone', 'RINGTONE_SETTINGS', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAvailableRingtones() async {
    try {
      final ringtones = await _ringtoneService.getAvailableRingtones();
      setState(() {
        _availableRingtones = ringtones;
      });
    } catch (e) {
      Log.e('Error loading available ringtones', 'RINGTONE_SETTINGS', e);
    }
  }

  Future<void> _downloadRingtoneFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      // Extract filename from URL or use default
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      String fileName = 'ringtone_${DateTime.now().millisecondsSinceEpoch}';
      
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        if (lastSegment.contains('.')) {
          fileName = lastSegment;
        } else {
          fileName = '$lastSegment.mp3';
        }
      }

      // Ensure .mp3 extension
      if (!fileName.toLowerCase().endsWith('.mp3') &&
          !fileName.toLowerCase().endsWith('.wav') &&
          !fileName.toLowerCase().endsWith('.m4a') &&
          !fileName.toLowerCase().endsWith('.aac') &&
          !fileName.toLowerCase().endsWith('.ogg')) {
        fileName = '$fileName.mp3';
      }

      final filePath = await _ringtoneService.downloadRingtone(url, fileName);
      
      if (filePath != null) {
        // Set as current ringtone
        final name = fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac|ogg)$'), '');
        await _ringtoneService.setCustomRingtone(filePath, name: name, url: url);
        
        await _loadCurrentRingtone();
        await _loadAvailableRingtones();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ringtone downloaded and set: $name')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download ringtone')),
          );
        }
      }
    } catch (e) {
      Log.e('Error downloading ringtone', 'RINGTONE_SETTINGS', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _pickRingtoneFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        setState(() {
          _isLoading = true;
        });

        try {
          final savedPath = await _ringtoneService.saveRingtoneFromFile(sourcePath, fileName);
          
          if (savedPath != null) {
            final name = fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac|ogg)$'), '');
            await _ringtoneService.setCustomRingtone(savedPath, name: name);
            
            await _loadCurrentRingtone();
            await _loadAvailableRingtones();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ringtone set: $name')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to save ringtone')),
              );
            }
          }
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Log.e('Error picking ringtone', 'RINGTONE_SETTINGS', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _setRingtone(String filePath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(filePath);
      final fileName = file.path.split('/').last;
      final name = fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac|ogg)$'), '');
      
      await _ringtoneService.setCustomRingtone(filePath, name: name);
      await _loadCurrentRingtone();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ringtone set: $name')),
        );
      }
    } catch (e) {
      Log.e('Error setting ringtone', 'RINGTONE_SETTINGS', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearRingtone() async {
    await _ringtoneService.clearCustomRingtone();
    await _loadCurrentRingtone();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Using default ringtone')),
      );
    }
  }

  Future<void> _deleteRingtone(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ringtone'),
        content: const Text('Are you sure you want to delete this ringtone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await _ringtoneService.deleteRingtone(filePath);
      if (deleted) {
        await _loadCurrentRingtone();
        await _loadAvailableRingtones();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ringtone deleted')),
          );
        }
      }
    }
  }

  Future<void> _testRingtone() async {
    await _ringtoneService.playRingtone();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Playing ringtone...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Stop after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        _ringtoneService.stopRingtone();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringtone Settings'),
      ),
      body: _isLoading && _currentRingtoneName == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Ringtone
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Ringtone',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentRingtoneName ?? 'Default',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _testRingtone,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Test'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _clearRingtone,
                                child: const Text('Use Default'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Download from URL
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Ringtone',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'Ringtone URL',
                              hintText: 'https://example.com/ringtone.mp3',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isDownloading ? null : _downloadRingtoneFromUrl,
                              icon: _isDownloading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download),
                              label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Pick from Device
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select from Device',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickRingtoneFromDevice,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Choose File'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Available Ringtones
                  if (_availableRingtones.isNotEmpty) ...[
                    Text(
                      'Available Ringtones',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._availableRingtones.map((file) {
                      final filePath = file.path;
                      final fileName = filePath.split('/').last;
                      final isCurrent = filePath == _currentRingtonePath;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isCurrent ? Colors.blue.withOpacity(0.1) : null,
                        child: ListTile(
                          leading: Icon(
                            isCurrent ? Icons.check_circle : Icons.music_note,
                            color: isCurrent ? Colors.blue : null,
                          ),
                          title: Text(fileName),
                          subtitle: isCurrent ? const Text('Current ringtone') : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isCurrent)
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () => _setRingtone(filePath),
                                  tooltip: 'Set as ringtone',
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteRingtone(filePath),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                          onTap: isCurrent ? null : () => _setRingtone(filePath),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}

