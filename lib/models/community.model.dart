import 'package:flutter/material.dart';
import 'group.model.dart';

class CommunityModel {
  final int id;
  final String name;
  final List<int> groupIds;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.groupIds,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      groupIds: List<int>.from(json['group_ids'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group_ids': groupIds,
      'metadata': metadata,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Helper to get the number of inner groups
  int get innerGroupsCount => groupIds.length;
}

// Model for community inner groups (groups within a community)
class CommunityGroupModel {
  final int conversationId;
  final String title;
  final String type;
  final List<GroupMember> members;
  final CommunityGroupMetadata? metadata;
  final String? lastMessageAt;
  final String? role;
  final String joinedAt;

  CommunityGroupModel({
    required this.conversationId,
    required this.title,
    required this.type,
    required this.members,
    this.metadata,
    this.lastMessageAt,
    this.role,
    required this.joinedAt,
  });

  factory CommunityGroupModel.fromJson(Map<String, dynamic> json) {
    return CommunityGroupModel(
      conversationId: json['conversationId'] ?? json['conversation_id'] ?? 0,
      title: json['title'] ?? '',
      type: json['type'] ?? 'community_group',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((member) => GroupMember.fromJson(member))
              .toList() ??
          [],
      metadata: json['metadata'] != null
          ? CommunityGroupMetadata.fromJson(json['metadata'])
          : null,
      lastMessageAt: json['lastMessageAt'] ?? json['last_message_at'],
      role: json['role'],
      joinedAt:
          json['joinedAt'] ??
          json['joined_at'] ??
          DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'title': title,
      'type': type,
      'members': members.map((member) => member.toJson()).toList(),
      'metadata': metadata?.toJson(),
      'lastMessageAt': lastMessageAt,
      'role': role,
      'joinedAt': joinedAt,
    };
  }

  // Helper to check if current time is within active time slots
  bool get isActiveNow {
    if (metadata?.activeTimeSlots == null ||
        metadata!.activeTimeSlots.isEmpty) {
      return true; // If no time restrictions, always active
    }

    final now = DateTime.now();
    final currentDay = now.weekday % 7; // Convert to 0-6 where Sunday = 0
    final currentTime = TimeOfDay.fromDateTime(now);

    // Check if today is an active day
    if (!metadata!.activeDays.contains(currentDay)) {
      return false;
    }

    // Check if current time is within any active time slot
    for (final timeSlot in metadata!.activeTimeSlots) {
      if (_isTimeInRange(currentTime, timeSlot.startTime, timeSlot.endTime)) {
        return true;
      }
    }

    return false;
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Same day range
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
}

class CommunityGroupMetadata {
  final String timezone;
  final List<int> activeDays;
  final int communityId;
  final List<ActiveTimeSlot> activeTimeSlots;
  final GroupLastMessage? lastMessage;
  final int totalMessages;
  final String? createdAt;
  final int createdBy;

  CommunityGroupMetadata({
    required this.timezone,
    required this.activeDays,
    required this.communityId,
    required this.activeTimeSlots,
    this.lastMessage,
    required this.totalMessages,
    this.createdAt,
    required this.createdBy,
  });

  factory CommunityGroupMetadata.fromJson(Map<String, dynamic> json) {
    return CommunityGroupMetadata(
      timezone: json['timezone'] ?? 'UTC',
      activeDays: List<int>.from(json['active_days'] ?? []),
      communityId: json['community_id'] ?? 0,
      activeTimeSlots:
          (json['active_time_slots'] as List<dynamic>?)
              ?.map((slot) => ActiveTimeSlot.fromJson(slot))
              .toList() ??
          [],
      lastMessage: json['last_message'] != null
          ? GroupLastMessage.fromJson(json['last_message'])
          : null,
      totalMessages: json['total_messages'] ?? json['totalMessages'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'],
      createdBy: json['created_by'] ?? json['createdBy'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timezone': timezone,
      'active_days': activeDays,
      'community_id': communityId,
      'active_time_slots': activeTimeSlots
          .map((slot) => slot.toJson())
          .toList(),
      'last_message': lastMessage?.toJson(),
      'total_messages': totalMessages,
      'created_at': createdAt,
      'created_by': createdBy,
    };
  }
}

class ActiveTimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  ActiveTimeSlot({required this.startTime, required this.endTime});

  factory ActiveTimeSlot.fromJson(Map<String, dynamic> json) {
    return ActiveTimeSlot(
      startTime: _parseTimeOfDay(json['start_time'] ?? '00:00'),
      endTime: _parseTimeOfDay(json['end_time'] ?? '23:59'),
    );
  }

  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() {
    return {
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
    };
  }

  String get displayTime {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
