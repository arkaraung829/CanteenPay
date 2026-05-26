/// Device ID Service
///
/// Provides a persistent unique device identifier stored in SharedPreferences.
/// Used for FCM token management and analytics.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService _instance = DeviceIdService._();
  factory DeviceIdService() => _instance;

  static const String _storageKey = 'canteen_device_id';

  String? _cachedId;

  /// Returns the persistent device ID, generating one on first call.
  Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_storageKey);

    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_storageKey, id);
      if (kDebugMode) {
        debugPrint('DeviceIdService: generated new device ID: $id');
      }
    }

    _cachedId = id;
    return id;
  }
}
