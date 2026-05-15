import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme-color.provider.dart';

class MessageRecommendations extends ConsumerWidget {
  final List<String> recommendations;
  final Function(String) onRecommendationTap;

  const MessageRecommendations({
    super.key,
    required this.recommendations,
    required this.onRecommendationTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      // margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 0,
          children: recommendations.map((recommendation) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child:
                  // BackdropFilter(
                  //   filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  //   child:
                  InkWell(
                    onTap: () => onRecommendationTap(recommendation),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: themeColor.primary.withAlpha(35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        recommendation,
                        style: TextStyle(
                          color: themeColor.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              // ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
