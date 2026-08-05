import 'package:ntp/ntp.dart';
import 'package:flutter/foundation.dart';

class TimeSecurityService {
  /// Fetches the true current time from the network.
  /// Falls back to local time if network is unavailable, but logs/warns.
  static Future<DateTime> getSecureTime() async {
    try {
      if (kIsWeb) {
        // NTP might not work directly in web without a CORS-friendly proxy,
        // so we just return local time or use a REST API time service if needed.
        return DateTime.now();
      }
      
      // Fetch time from NTP server with 5 seconds timeout
      final int offset = await NTP.getNtpOffset(
        localTime: DateTime.now(),
        lookUpAddress: 'time.google.com',
        timeout: const Duration(seconds: 5),
      );
      
      return DateTime.now().add(Duration(milliseconds: offset));
    } catch (e) {
      debugPrint('Failed to get secure time from NTP: $e');
      // If we can't get network time (e.g. offline), we have to trust local time
      // or block the action depending on strictness. For now, fallback to local.
      return DateTime.now();
    }
  }

  /// Checks if the local time has been tampered with (differs by more than 5 minutes from NTP)
  static Future<bool> isTimeTampered() async {
    try {
      if (kIsWeb) return false;
      
      final int offset = await NTP.getNtpOffset(
        localTime: DateTime.now(),
        lookUpAddress: 'time.google.com',
        timeout: const Duration(seconds: 5),
      );
      
      // If offset is more than 5 minutes (300,000 ms), consider it tampered
      return offset.abs() > 300000;
    } catch (e) {
      // Cannot verify - Fail Closed to prevent offline spoofing
      return true;
    }
  }
}
