import 'dart:async';
import 'package:amigo/db/repositories/call.repo.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/auth.api-client.dart';
import '../../models/call.model.dart';
import '../../providers/call.provider.dart';
import '../../providers/theme-color.provider.dart';

class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key});

  @override
  ConsumerState<CallsPage> createState() => CallsPageState();
}

class CallsPageState extends ConsumerState<CallsPage>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  List<CallHistoryItem> _callHistory = [];
  bool _isLoading =
      false; // Start with false, will be set to true only if needed
  String? _error;
  Timer? _debounceTimer;
  bool _isLoadingInProgress = false;
  bool _hasLoadedOnce = false; // Track if we've loaded at least once

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load call history once on init (without showing loading if we have local data)
    _loadCallHistory(showLoading: false);
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
      // Use debouncing to avoid immediate refresh
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && !_isLoadingInProgress) {
          _loadCallHistory(showLoading: false);
        }
      });
    }
  }

  // This method will be called when the page becomes visible
  void onPageVisible() {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Set a new debounce timer to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isLoadingInProgress) {
        _loadCallHistory(showLoading: false);
      }
    });
  }

  // Future<void> _loadCallHistory({bool showLoading = true}) async {
  //   if (showLoading) {
  //     setState(() {
  //       _isLoading = true;
  //       _error = null;
  //     });
  //   }

  //   try {
  //     final response = await _apiService.authenticatedGet(
  //       '/call/history?limit=50',
  //     );
  //     final data = response.data;

  //     if (data['success'] == true && data['data'] != null) {
  //       final List<dynamic> callsData = data['data'];
  //       setState(() {
  //         _callHistory = callsData
  //             .map((call) => CallHistoryItem.fromJson(call))
  //             .toList();
  //         _isLoading = false;
  //       });
  //     } else {
  //       setState(() {
  //         _error = data['message'] ?? 'Failed to load call history';
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _error = 'Error loading call history: $e';
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> _loadCallHistory({bool showLoading = true}) async {
    // Prevent multiple simultaneous loads
    if (_isLoadingInProgress) return;

    // _isLoadingInProgress = true;
    final callRepo = CallRepository();
    final currentUser = await UserUtils().getUserDetails();

    // Step 1: Load from local DB immediately (no loading spinner if we have data)
    try {
      final List<CallModel> localCalls = await callRepo.getAllCalls(
        currentUser?.id ?? 0,
      );
      if (mounted) {
        setState(() {
          _callHistory = localCalls.map(_mapCallModelToHistoryItem).toList();
          // Only show loading if explicitly requested AND we have no local data AND haven't loaded before
          _isLoading = showLoading && localCalls.isEmpty && !_hasLoadedOnce;
          _error = null;
        });
        _hasLoadedOnce = true;
      }
    } catch (e) {
      // If local DB fails, show loading only if we don't have data and haven't loaded before
      if (mounted && _callHistory.isEmpty && !_hasLoadedOnce) {
        setState(() {
          _isLoading = showLoading;
          _error = null;
        });
      }
    }

    // Step 2: Fetch from server in background and update
    try {
      final response = await _apiService.authenticatedGet(
        '/call/history?limit=50',
      );
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        final List<dynamic> callsData = data['data'];
        final List<CallModel> calls = callsData
            .map((c) => CallModel.fromJson(c))
            .toList();

        // Save to local DB
        await callRepo.insertCalls(calls);

        // Update UI with fresh data from server, preserving duration if it exists
        if (mounted) {
          final newHistory = calls.map(_mapCallModelToHistoryItem).toList();

          // Merge with existing data to preserve durationSeconds if server data has 0
          final mergedHistory = _mergeCallHistory(_callHistory, newHistory);

          // Only update if the data actually changed to prevent unnecessary rebuilds
          if (_hasDataChanged(_callHistory, mergedHistory)) {
            setState(() {
              _callHistory = mergedHistory;
              _isLoading = false;
              _error = null;
            });
          } else {
            // Still update loading state even if data didn't change
            if (_isLoading) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
      } else {
        if (mounted && _callHistory.isEmpty) {
          setState(() {
            _error = data['message'] ?? 'Failed to load call history';
            _isLoading = false;
          });
        } else if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Server fetch failed, but we already showed local data
      // Only show error if we have no data at all
      if (mounted && _callHistory.isEmpty && !_hasLoadedOnce) {
        setState(() {
          _error = 'Failed to load call history';
          _isLoading = false;
        });
      } else if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      // If we have local data, silently fail the background update
    } finally {
      _isLoadingInProgress = false;
    }
  }

  // Helper method to merge call history, preserving duration from old data if new data has 0
  List<CallHistoryItem> _mergeCallHistory(
    List<CallHistoryItem> oldList,
    List<CallHistoryItem> newList,
  ) {
    // Create a map of old calls by ID for quick lookup
    final oldMap = <int, CallHistoryItem>{};
    for (final call in oldList) {
      oldMap[call.id] = call;
    }

    // Merge new calls with old data, preserving duration if new has 0
    return newList.map((newCall) {
      final oldCall = oldMap[newCall.id];
      if (oldCall != null &&
          newCall.durationSeconds == 0 &&
          oldCall.durationSeconds > 0) {
        // Preserve duration from old data
        return CallHistoryItem(
          id: newCall.id,
          callerId: newCall.callerId,
          calleeId: newCall.calleeId,
          contactId: newCall.contactId,
          contactName: newCall.contactName,
          startedAt: newCall.startedAt,
          answeredAt: newCall.answeredAt,
          endedAt: newCall.endedAt,
          durationSeconds: oldCall.durationSeconds, // Preserve old duration
          status: newCall.status,
          reason: newCall.reason,
          type: newCall.type,
        );
      }
      return newCall;
    }).toList();
  }

  // Helper method to check if call history data has changed
  bool _hasDataChanged(
    List<CallHistoryItem> oldList,
    List<CallHistoryItem> newList,
  ) {
    if (oldList.length != newList.length) return true;

    for (int i = 0; i < oldList.length; i++) {
      final old = oldList[i];
      final new_ = newList[i];
      if (old.id != new_.id ||
          old.status != new_.status ||
          old.durationSeconds != new_.durationSeconds ||
          old.startedAt != new_.startedAt) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Watch for call service state changes
    ref.listen<CallServiceState>(callServiceProvider, (previous, next) {
      // Refresh call history when call service state changes (e.g., call ends)
      // Use debouncing to avoid too many refreshes
      // Add a delay to allow server to update call status
      if (previous?.hasActiveCall == true && next.hasActiveCall == false) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted && !_isLoadingInProgress) {
            _loadCallHistory(showLoading: false);
          }
        });
      }
    });

    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFB),

      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: themeColor.primary,
          leadingWidth: 60,
          leading: Container(
            margin: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.call_rounded, color: Colors.white, size: 24),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Call history',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => _loadCallHistory(showLoading: false),
              ),
            ),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () => _loadCallHistory(showLoading: false),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final themeColor = ref.watch(themeColorProvider);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: themeColor.primary),
      );
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
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor.primary,
              ),
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
      color: Colors.white,
      shadowColor: Colors.grey.withAlpha(20),
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
        trailing: Consumer(
          builder: (context, ref, child) {
            final callServiceState = ref.watch(callServiceProvider);
            final bool canCall = !callServiceState.hasActiveCall;
            final themeColor = ref.watch(themeColorProvider);

            return IconButton(
              icon: Icon(
                Icons.call,
                color: canCall ? themeColor.primary : Colors.grey,
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
        return Icons.call_rounded;
      case CallStatus.missed:
        return Icons.call_missed_rounded;
      case CallStatus.declined:
        return Icons.call_end_rounded;
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
      final callServiceNotifier = ref.read(callServiceProvider.notifier);
      await callServiceNotifier.initiateCall(userId, userName, null);

      if (context.mounted) {
        Navigator.of(context).pushNamed('/call');
      }
    } catch (e) {
      if (context.mounted) {
        final themeColor = ref.watch(themeColorProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start call: Please check your internet connection',
            ),
            backgroundColor: themeColor.primary,
          ),
        );
      }
    }
  }

  // Map persisted CallModel to UI-friendly CallHistoryItem
  CallHistoryItem _mapCallModelToHistoryItem(CallModel model) {
    return CallHistoryItem(
      id: model.id,
      callerId: model.callerId,
      calleeId: model.calleeId,
      contactId: model.contactId,
      contactName: model.contactName,
      startedAt: model.startedAt,
      answeredAt: model.answeredAt,
      endedAt: model.endedAt,
      durationSeconds: model.durationSeconds,
      status: model.status,
      reason: model.reason,
      type: model.callType,
    );
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
