import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/unified_media_service.dart';

class HashDemoScreen extends StatefulWidget {
  const HashDemoScreen({Key? key}) : super(key: key);

  @override
  State<HashDemoScreen> createState() => _HashDemoScreenState();
}

class _HashDemoScreenState extends State<HashDemoScreen> {
  String _selectedFileName = '';
  String _fileHash = '';
  bool _isLoading = false;
  Uint8List? _selectedFileBytes;

  Future<void> _pickFile() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final fileData = await UnifiedMediaService.pickDocument(context);
      if (fileData != null) {
        final bytes = fileData['bytes'] as Uint8List;
        final fileName = fileData['fileName'] as String;
        final fileSize = fileData['fileSize'] as int;
        
        setState(() {
          _selectedFileBytes = bytes;
          _selectedFileName = '$fileName (${(fileSize / 1024).toStringAsFixed(1)} KB)';
          _fileHash = '';
        });
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void _hashText(String text) {
    if (text.isEmpty) return;
    
    final bytes = utf8.encode(text);
    final digest = sha256.convert(bytes);
    setState(() {
      _fileHash = digest.toString();
    });
  }

  void _hashFile() {
    if (_selectedFileBytes == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Simulate processing time
    Future.delayed(const Duration(milliseconds: 500), () {
      final digest = sha256.convert(_selectedFileBytes!);
      setState(() {
        _fileHash = digest.toString();
        _isLoading = false;
      });
    });
  }

  void _hashSaltedText(String text, String salt) {
    if (text.isEmpty || salt.isEmpty) return;
    
    final saltedText = text + salt;
    final bytes = utf8.encode(saltedText);
    final digest = sha256.convert(bytes);
    setState(() {
      _fileHash = digest.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hash Demo'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Selection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File Selection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Pick File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_selectedFileName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Text Hashing Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Text Hashing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter text to hash',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _hashText,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Salted Hashing Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Salted Hashing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Enter text',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (text) {
                        // Get salt from somewhere or use a default
                        final salt = 'default_salt_123';
                        _hashSaltedText(text, salt);
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // File Hashing Section
            if (_selectedFileBytes != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'File Hashing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _hashFile,
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.fingerprint),
                        label: Text(_isLoading ? 'Processing...' : 'Hash File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Hash Result Section
            if (_fileHash.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hash Result (SHA-256)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          _fileHash,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _fileHash));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Hash copied to clipboard')),
                                );
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy Hash'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Info Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About Hashing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SHA-256 is a cryptographic hash function that produces a 256-bit (32-byte) hash value. '
                      'It\'s commonly used for data integrity verification and digital signatures.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 