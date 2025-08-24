import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
  /// Generates SHA-256 hash of a string
  static String generateSHA256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates SHA-256 hash of bytes
  static String generateSHA256FromBytes(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates SHA-256 hash of a file (for file integrity verification)
  static Future<String> generateFileSHA256(List<int> fileBytes) async {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  /// Verifies if a string matches a given SHA-256 hash
  static bool verifySHA256(String input, String expectedHash) {
    final actualHash = generateSHA256(input);
    return actualHash == expectedHash;
  }

  /// Generates a secure random salt and returns the salted hash
  static String generateSaltedSHA256(String input, String salt) {
    final saltedInput = input + salt;
    return generateSHA256(saltedInput);
  }

  /// Generates a random salt (for password hashing)
  static String generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return generateSHA256(random);
  }

  /// Generates a hash for chat message integrity verification
  static String generateMessageHash(String message, String senderId, DateTime timestamp) {
    final messageData = '$message|$senderId|${timestamp.millisecondsSinceEpoch}';
    return generateSHA256(messageData);
  }

  /// Verifies message integrity using hash
  static bool verifyMessageIntegrity(String message, String senderId, DateTime timestamp, String expectedHash) {
    final actualHash = generateMessageHash(message, senderId, timestamp);
    return actualHash == expectedHash;
  }
} 