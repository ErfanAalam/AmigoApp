import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/call_model.dart';
import '../../api/api_service.dart';
import '../../services/call_service.dart';

class CallsPage extends StatefulWidget {
  const CallsPage({super.key});

  @override
  State<CallsPage> createState() => CallsPageState();
}

class CallsPageState extends State<CallsPage> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  List<CallHistoryItem> _callHistory = [];
  bool _isLoading = true;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCallHistory();

    // Add a post-frame callback to ensure the page is fully loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCallHistory(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reload call history when app comes back to foreground
      _loadCallHistory();
    }
  }

  // This method will be called when the page becomes visible
  void onPageVisible() {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Set a new debounce timer to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isLoading) {
        _loadCallHistory(showLoading: false);
      }
    });
  }

  Future<void> _loadCallHistory({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await _apiService.authenticatedGet(
        '/call/history?limit=50',
      );
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        final List<dynamic> callsData = data['data'];
        setState(() {
          _callHistory = callsData
              .map((call) => CallHistoryItem.fromJson(call))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load call history';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading call history: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger refresh when the page is built (becomes visible) with debouncing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted && !_isLoading) {
            _loadCallHistory(showLoading: false);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFB),
      appBar: AppBar(
        leadingWidth: 40, // Reduce leading width to minimize gap
        leading: Padding(
          padding: EdgeInsets.only(left: 16), // Add some left padding
          child: Icon(Icons.call, color: Colors.white),
        ),
        titleSpacing: 8,
        title: const Text(
          'Calls',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadCallHistory,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadCallHistory, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load call history, please try again later',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCallHistory,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_callHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No call history',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your call history will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _callHistory.length,
      itemBuilder: (context, index) {
        final call = _callHistory[index];
        return _buildCallHistoryItem(call);
      },
    );
  }

  Widget _buildCallHistoryItem(CallHistoryItem call) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCallStatusColor(call.status),
          child: Icon(_getCallIcon(call), color: Colors.white, size: 20),
        ),
        title: Text(
          call.contactName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCallDirectionIcon(call.type),
                  size: 16,
                  color: _getCallStatusColor(call.status),
                ),
                const SizedBox(width: 4),
                Text(
                  _getCallStatusText(call.status),
                  style: TextStyle(
                    color: _getCallStatusColor(call.status),
                    fontSize: 12,
                  ),
                ),
                if (call.durationSeconds > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• ${_formatDuration(call.durationSeconds)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _formatDateTime(call.startedAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: Consumer<CallService>(
          builder: (context, callService, child) {
            final bool canCall = !callService.hasActiveCall;
            return IconButton(
              icon: Icon(
                Icons.call,
                color: canCall ? Colors.teal : Colors.grey,
              ),
              onPressed: canCall
                  ? () => _initiateCall(call.contactId, call.contactName)
                  : null,
            );
          },
        ),
      ),
    );
  }

  IconData _getCallIcon(CallHistoryItem call) {
    switch (call.status) {
      case CallStatus.answered:
        return Icons.call;
      case CallStatus.missed:
        return Icons.call_missed;
      case CallStatus.declined:
        return Icons.call_end;
      default:
        return Icons.call_outlined;
    }
  }

  IconData _getCallDirectionIcon(CallType type) {
    return type == CallType.incoming ? Icons.call_received : Icons.call_made;
  }

  Color _getCallStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.answered:
        return Colors.green;
      case CallStatus.missed:
        return Colors.red;
      case CallStatus.declined:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getCallStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.answered:
        return 'Answered';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.ended:
        return 'Ended';
      default:
        return status.value;
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Older
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _initiateCall(int userId, String userName) async {
    try {
      final callService = Provider.of<CallService>(context, listen: false);
      await callService.initiateCall(userId, userName, null);

      if (context.mounted) {
        Navigator.of(context).pushNamed('/call');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Data model for call history items
class CallHistoryItem {
  final int id;
  final int callerId;
  final int calleeId;
  final int contactId; // The other person's ID
  final String contactName; // The other person's name
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final CallStatus status;
  final String? reason;
  final CallType type; // incoming or outgoing

  CallHistoryItem({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.contactId,
    required this.contactName,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    required this.durationSeconds,
    required this.status,
    this.reason,
    required this.type,
  });

  factory CallHistoryItem.fromJson(Map<String, dynamic> json) {
    return CallHistoryItem(
      id: _parseInt(json['id']),
      callerId: _parseInt(json['caller_id']),
      calleeId: _parseInt(json['callee_id']),
      contactId: _parseInt(json['contact_id']),
      contactName: json['contact_name']?.toString() ?? 'Unknown',
      startedAt: DateTime.parse(json['started_at']),
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'])
          : null,
      durationSeconds: _parseInt(json['duration_seconds']),
      status: CallStatus.fromString(json['status']),
      reason: json['reason']?.toString(),
      type: json['call_type'] == 'incoming'
          ? CallType.incoming
          : CallType.outgoing,
    );
  }

  // Helper method to safely parse integers
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}
