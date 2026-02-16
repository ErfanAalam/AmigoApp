import 'dart:io';

import 'package:amigo/types/network.types.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/rendering.dart';

class Network {
  final Connectivity _connectivity = Connectivity();

  void networkType() {
    _connectivity.onConnectivityChanged.listen((result) {
      debugPrint(result.toString());
      if (result == ConnectivityResult.none) {
        debugPrint("No network");
      } else if (result == ConnectivityResult.mobile) {
        debugPrint("Mobile data");
      } else if (result == ConnectivityResult.vpn) {
        debugPrint("VPN connected");
      } else if (result == ConnectivityResult.wifi) {
        debugPrint("WiFi connected");
      }
    });
  }

  Future<int?> pingServer() async {
    final stopwatch = Stopwatch()..start();

    try {
      final request = await HttpClient().getUrl(
        Uri.parse("https://api.yourapp.com/ping"),
      );

      final response = await request.close();

      if (response.statusCode == 200) {
        stopwatch.stop();
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<NetworkState> checkNetwork() async {
    final ms = await pingServer();

    if (ms == null) return NetworkState.offline;

    if (ms < 300) return NetworkState.good;
    if (ms < 1000) return NetworkState.medium;
    if (ms < 3000) return NetworkState.slow;

    return NetworkState.verySlow;
  }
}
