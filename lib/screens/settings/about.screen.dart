import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme-color.provider.dart';
import '../../services/socket/transport.manager.dart';
import '../../services/socket/transport.service.dart';
import '../../types/network.types.dart';
import '../../ui/app-bar.widget.dart';
import '../../ui/settings-tile.widget.dart';
import '../../utils/network.utils.dart';
import '../../utils/user.utils.dart';
import '../debug/debug-menu.screen.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _appVersion = '';
  Timer? _debugTimer;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _debugTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final v = await UserUtils().getAppVersion();
    if (!mounted) return;
    setState(() => _appVersion = v);
  }

  void _showNetworkDiagnostics() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const _NetworkDiagnosticsDialog(),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: const AmigoAppBar(title: 'About', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120, top: 8),
        children: [
          SettingsCard(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) {
                  _debugTimer = Timer(const Duration(seconds: 5), () {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DebugMenuScreen(),
                      ),
                    );
                  });
                },
                onLongPressEnd: (_) {
                  _debugTimer?.cancel();
                  _debugTimer = null;
                },
                onLongPressCancel: () {
                  _debugTimer?.cancel();
                  _debugTimer = null;
                },
                child: SettingsValueRow(
                  label: 'App Version',
                  value: _appVersion.isNotEmpty ? 'v$_appVersion' : 'Loading…',
                ),
              ),
              SettingsTile(
                icon: Icons.network_check_rounded,
                iconBackgroundColor: themeColor.primary,
                title: 'Network Diagnostics',
                subtitle: 'Check connection health & latency',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 22,
                ),
                onTap: _showNetworkDiagnostics,
              ),
            ],
          ),
          // Padding(
          //   padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          //   child: Text(
          //     'Long-press the version row for 5 seconds to open the developer debug menu.',
          //     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _NetworkDiagnosticsDialog extends StatefulWidget {
  const _NetworkDiagnosticsDialog();

  @override
  State<_NetworkDiagnosticsDialog> createState() =>
      _NetworkDiagnosticsDialogState();
}

class _NetworkDiagnosticsDialogState extends State<_NetworkDiagnosticsDialog> {
  NetworkState? _networkState;
  TransportType? _transportType;
  TransportConnectionState? _transportConnectionState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() => _isLoading = true);
    final state = await NetworkConnectivityUtil().checkNetwork();
    final manager = TransportManager();
    if (mounted) {
      setState(() {
        _networkState = state;
        _transportType = manager.currentTransportType;
        _transportConnectionState = manager.connectionState;
        _isLoading = false;
      });
    }
  }

  Color _qualityColor(NetworkQuality q) => switch (q) {
    NetworkQuality.excellent => Colors.green,
    NetworkQuality.good => Colors.lightGreen,
    NetworkQuality.fair => Colors.amber,
    NetworkQuality.poor => Colors.orange,
    NetworkQuality.veryPoor || NetworkQuality.offline => Colors.red,
  };

  IconData _connectionTypeIcon(NetworkConnectionType t) => switch (t) {
    NetworkConnectionType.wifi => Icons.wifi,
    NetworkConnectionType.mobile => Icons.signal_cellular_alt,
    NetworkConnectionType.ethernet => Icons.cable,
    NetworkConnectionType.vpn => Icons.vpn_lock,
    NetworkConnectionType.other ||
    NetworkConnectionType.none => Icons.device_unknown,
  };

  String _transportLabel(TransportType? t) => switch (t) {
    TransportType.websocket => 'WebSocket',
    TransportType.longPolling => 'Long Polling',
    null => 'None',
  };

  String _connectionStateLabel(TransportConnectionState? s) => switch (s) {
    TransportConnectionState.connected => 'Connected',
    TransportConnectionState.connecting => 'Connecting',
    TransportConnectionState.reconnecting => 'Reconnecting',
    TransportConnectionState.disconnected => 'Disconnected',
    TransportConnectionState.error => 'Error',
    null => 'Unknown',
  };

  Color _connectionStateColor(TransportConnectionState? s) => switch (s) {
    TransportConnectionState.connected => Colors.green,
    TransportConnectionState.connecting ||
    TransportConnectionState.reconnecting => Colors.amber,
    _ => Colors.red,
  };

  Widget _statRow({required String label, required Widget value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(flex: 5, child: value),
        ],
      ),
    );
  }

  Widget _boolValue(bool v) => Row(
    children: [
      Icon(
        v ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: v ? Colors.green : Colors.red,
      ),
      const SizedBox(width: 4),
      Text(
        v ? 'Yes' : 'No',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: v ? Colors.green : Colors.red,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final lastChecked = _networkState?.lastChecked;
    final timeStr = lastChecked != null
        ? '${lastChecked.hour.toString().padLeft(2, '0')}:'
              '${lastChecked.minute.toString().padLeft(2, '0')}:'
              '${lastChecked.second.toString().padLeft(2, '0')}'
        : '—';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.network_check, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Network Diagnostics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: [
                            _statRow(
                              label: 'Connection Type',
                              value: Row(
                                children: [
                                  Icon(
                                    _connectionTypeIcon(
                                      _networkState!.connectionType,
                                    ),
                                    size: 16,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _networkState!.connectionType.name
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statRow(
                              label: 'Network Quality',
                              value: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _qualityColor(
                                        _networkState!.quality,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_networkState!.quality.name}'
                                    '${_networkState!.pingLatencyMs != null ? ' (${_networkState!.pingLatencyMs}ms)' : ''}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _qualityColor(
                                        _networkState!.quality,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statRow(
                              label: 'Server Reachable',
                              value: _boolValue(
                                _networkState!.isServerReachable,
                              ),
                            ),
                            _statRow(
                              label: 'WebSocket',
                              value: _boolValue(
                                _networkState!.isWebSocketAvailable,
                              ),
                            ),
                            _statRow(
                              label: 'Long Polling',
                              value: _boolValue(
                                _networkState!.isPollingAvailable,
                              ),
                            ),
                            _statRow(
                              label: 'Active Transport',
                              value: Text(
                                _transportLabel(_transportType),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _statRow(
                              label: 'Connection State',
                              value: Text(
                                _connectionStateLabel(
                                  _transportConnectionState,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _connectionStateColor(
                                    _transportConnectionState,
                                  ),
                                ),
                              ),
                            ),
                            _statRow(
                              label: 'Last Checked',
                              value: Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                TextButton(
                  onPressed: _isLoading ? null : _runCheck,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 0),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Run Again',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
