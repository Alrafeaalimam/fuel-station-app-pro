import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityUtil {
  /// Hashes a plain text password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain text password matches a stored hash
  static bool verifyPassword(String password, String storedHash) {
    return hashPassword(password) == storedHash.trim();
  }
}
