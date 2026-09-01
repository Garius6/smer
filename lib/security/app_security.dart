import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppSecurity {
  AppSecurity({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _databasePasswordKey = 'database_password';
  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';
  static const _pinLengthKey = 'pin_length';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  Future<String> databasePassword() async {
    final existing = await _storage.read(key: _databasePasswordKey);
    if (existing != null) return existing;
    final password = _randomValue();
    await _storage.write(key: _databasePasswordKey, value: password);
    return password;
  }

  Future<bool> hasPin() async =>
      await _storage.read(key: _pinHashKey) != null &&
      await _storage.read(key: _pinSaltKey) != null;

  Future<void> setPin(String pin) async {
    final salt = _randomValue();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hashPin(pin, salt));
    await _storage.write(key: _pinLengthKey, value: '${pin.length}');
  }

  Future<int> pinLength() async =>
      int.tryParse(await _storage.read(key: _pinLengthKey) ?? '') ?? 6;

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final hash = await _storage.read(key: _pinHashKey);
    return salt != null && hash != null && hash == hashPin(pin, salt);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuthentication.canCheckBiometrics;
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: 'Подтвердите личность, чтобы открыть дневник СМЭР.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _randomValue() => base64UrlEncode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );
}
