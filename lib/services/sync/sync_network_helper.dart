import 'dart:io';

import 'package:flutter/foundation.dart';

class SyncNetworkHelper {
  static const int defaultPort = 48921;

  /// Retrieves the most likely local IP address for LAN / Hotspot peer connection
  static Future<String?> getLocalIpAddress() async {
    if (kIsWeb) return '127.0.0.1';

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final addresses = <String>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            addresses.add(addr.address);
          }
        }
      }

      if (addresses.isEmpty) return null;

      // Priority 1: Hotspot ranges (192.168.43.x, 172.20.10.x)
      for (final ip in addresses) {
        if (ip.startsWith('192.168.43.') || ip.startsWith('172.20.10.')) {
          return ip;
        }
      }

      // Priority 2: Standard private LAN ranges (192.168.x.x)
      for (final ip in addresses) {
        if (ip.startsWith('192.168.')) {
          return ip;
        }
      }

      // Priority 3: 10.x.x.x or 172.16-31.x.x
      for (final ip in addresses) {
        if (ip.startsWith('10.') || ip.startsWith('172.')) {
          return ip;
        }
      }

      return addresses.first;
    } catch (_) {
      return null;
    }
  }

  /// Returns user-friendly device name (e.g. "MacBook Pro", "Android Device")
  static String getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isMacOS) return 'Mac Desktop';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux Desktop';
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone / iPad';
    return 'Cashflow Device';
  }
}
