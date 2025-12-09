import 'package:flutter/material.dart';
import '../services/socket/websocket_service.dart';

class WebSocketStatusWidget extends StatelessWidget {
  const WebSocketStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final websocketService = WebSocketService();

    return StreamBuilder<WebSocketConnectionState>(
      stream: websocketService.connectionStateStream,
      initialData: websocketService.connectionState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? WebSocketConnectionState.disconnected;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(state),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _getStatusIcon(state),
              const SizedBox(width: 4),
              Text(
                _getStatusText(state),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return Colors.green;
      case WebSocketConnectionState.connecting:
      case WebSocketConnectionState.reconnecting:
        return Colors.orange;
      case WebSocketConnectionState.error:
        return Colors.red;
      case WebSocketConnectionState.disconnected:
        return Colors.grey;
    }
  }

  Widget _getStatusIcon(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return const Icon(Icons.wifi, color: Colors.white, size: 16);
      case WebSocketConnectionState.connecting:
      case WebSocketConnectionState.reconnecting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case WebSocketConnectionState.error:
        return const Icon(Icons.error, color: Colors.white, size: 16);
      case WebSocketConnectionState.disconnected:
        return const Icon(Icons.wifi_off, color: Colors.white, size: 16);
    }
  }

  String _getStatusText(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return 'Connected';
      case WebSocketConnectionState.connecting:
        return 'Connecting...';
      case WebSocketConnectionState.reconnecting:
        return 'Reconnecting...';
      case WebSocketConnectionState.error:
        return 'Error';
      case WebSocketConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}
