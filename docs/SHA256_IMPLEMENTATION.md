# SHA-256 Implementation in SOC Chat App

## Overview

This document explains the SHA-256 hashing implementation added to the SOC Chat App. SHA-256 is a cryptographic hash function that produces a 256-bit (32-byte) hash value.

## What is SHA-256?

SHA-256 (Secure Hash Algorithm 256-bit) is:
- A cryptographic hash function
- Deterministic (same input always produces same output)
- One-way (cannot be reversed)
- Collision-resistant
- Widely used for data integrity verification

## Implementation Details

### 1. HashService Class (`lib/services/hash_service.dart`)

The main service provides the following methods:

#### Basic Hashing
```dart
// Hash a string
String hash = HashService.generateSHA256("Hello World");

// Hash bytes
String hash = HashService.generateSHA256FromBytes(bytes);

// Hash a file
String fileHash = await HashService.generateFileSHA256(fileBytes);
```

#### Verification
```dart
// Verify if a string matches a hash
bool isValid = HashService.verifySHA256("Hello World", expectedHash);
```

#### Salted Hashing (for passwords)
```dart
// Generate a salt
String salt = HashService.generateSalt();

// Create salted hash
String saltedHash = HashService.generateSaltedSHA256("password", salt);
```

#### Message Integrity (for chat)
```dart
// Generate message hash
String messageHash = HashService.generateMessageHash(
  message, 
  senderId, 
  timestamp
);

// Verify message integrity
bool isValid = HashService.verifyMessageIntegrity(
  message, 
  senderId, 
  timestamp, 
  expectedHash
);
```

### 2. Demo Screen (`lib/screens/hash_demo_screen.dart`)

A comprehensive demo screen that shows:
- Text hashing
- Salted hashing
- File hashing
- Hash verification
- Educational information about SHA-256

## Usage Examples

### 1. Basic Text Hashing
```dart
import '../services/hash_service.dart';

String text = "Hello World";
String hash = HashService.generateSHA256(text);
print(hash); // a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e
```

### 2. File Integrity Verification
```dart
import 'dart:io';
import '../services/hash_service.dart';

File file = File('document.pdf');
List<int> bytes = await file.readAsBytes();
String fileHash = await HashService.generateFileSHA256(bytes);

// Store this hash and later verify file hasn't been tampered with
bool isIntact = HashService.generateFileSHA256(bytes) == storedHash;
```

### 3. Password Hashing (with salt)
```dart
String password = "myPassword123";
String salt = HashService.generateSalt();
String hashedPassword = HashService.generateSaltedSHA256(password, salt);

// Store both hash and salt in database
// Later verify login:
bool isValidLogin = HashService.generateSaltedSHA256(inputPassword, storedSalt) == storedHash;
```

### 4. Chat Message Integrity
```dart
String message = "Hello there!";
String senderId = "user123";
DateTime timestamp = DateTime.now();

String messageHash = HashService.generateMessageHash(message, senderId, timestamp);

// Store message with hash in database
// Later verify message hasn't been modified:
bool isIntact = HashService.verifyMessageIntegrity(message, senderId, timestamp, storedHash);
```

## Security Considerations

### 1. Password Hashing
- Always use salt with passwords
- Never store plain text passwords
- Use strong, unique salts for each user

### 2. File Integrity
- Store file hashes separately from files
- Verify hashes before processing files
- Use for detecting file corruption or tampering

### 3. Message Integrity
- Hash includes sender ID and timestamp
- Prevents message tampering
- Useful for audit trails

## Dependencies

The implementation uses the `crypto` package:
```yaml
dependencies:
  crypto: ^3.0.3
```

## Accessing the Demo

1. Run the app
2. Navigate to Profile screen
3. Tap "SHA-256 Hash Demo" button
4. Experiment with different hashing features

## Common Use Cases

1. **Password Storage**: Hash passwords with salt before storing
2. **File Verification**: Generate hashes to verify file integrity
3. **Data Integrity**: Hash sensitive data to detect tampering
4. **Digital Signatures**: Use as part of digital signature schemes
5. **Blockchain**: Used in cryptocurrency and blockchain applications

## Performance Notes

- SHA-256 is fast and efficient
- Suitable for real-time applications
- Hash generation is deterministic and repeatable
- File hashing may take time for large files

## Best Practices

1. **Never store plain text**: Always hash sensitive data
2. **Use salt**: Always salt passwords and sensitive data
3. **Verify integrity**: Check hashes before processing data
4. **Secure storage**: Store hashes securely
5. **Regular verification**: Periodically verify data integrity

## Limitations

- SHA-256 is one-way (cannot decrypt)
- Not suitable for encryption (use AES for that)
- Hash collisions are theoretically possible but extremely unlikely
- File hashing requires reading entire file into memory

## Future Enhancements

1. Add support for other hash algorithms (SHA-512, SHA-3)
2. Implement HMAC for message authentication
3. Add support for streaming file hashing
4. Implement hash-based message authentication codes 