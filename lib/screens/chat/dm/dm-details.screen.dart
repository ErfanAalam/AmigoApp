import '../../../models/conversations.model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat-details.screen.dart';

class DmDetailsScreen extends ConsumerWidget {
  final DmModel dm;

  const DmDetailsScreen({super.key, required this.dm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChatDetailsScreen(dm: dm);
  }
}
