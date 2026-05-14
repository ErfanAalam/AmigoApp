import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app-colors.config.dart';
import '../../providers/chat-background.provider.dart';
import '../../providers/theme-color.provider.dart';
import '../../ui/app-bar.widget.dart';
import '../../ui/settings-tile.widget.dart';
import '../../ui/snackbar.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  Future<void> _pickBackground(WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked == null) return;
      await ref
          .read(chatBackgroundProvider.notifier)
          .setBackground(picked.path);
      Snack.show('Chat background updated');
    } catch (e) {
      Snack.error('Failed to set background: $e');
    }
  }

  void _openThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeColorProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Theme Color',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: AppColors.allThemes.map((theme) {
                  final selected = theme.name == current.name;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        ref
                            .read(themeColorProvider.notifier)
                            .setTheme(theme);
                        Snack.show('Theme changed to ${theme.name}');
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Colors.black87
                              : Colors.grey.shade200,
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withOpacity(0.35),
                            blurRadius: selected ? 10 : 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    final bgPath = ref.watch(chatBackgroundProvider);
    final hasCustomBg = bgPath != null && File(bgPath).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: const AmigoAppBar(title: 'Appearance', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120, top: 8),
        children: [
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                iconBackgroundColor: themeColor.primary,
                title: 'Theme Color',
                subtitle: themeColor.name,
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: themeColor.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                onTap: () => _openThemePicker(context, ref),
              ),
            ],
          ),
          SettingsSectionHeader(
            title: 'Chat background',
            color: themeColor.primary,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: hasCustomBg
                    ? FileImage(File(bgPath)) as ImageProvider
                    : const AssetImage('assets/images/chat_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(color: Colors.white.withAlpha(60)),
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.image_outlined,
                iconBackgroundColor: const Color(0xFF34C759),
                title: hasCustomBg
                    ? 'Change Background'
                    : 'Set Chat Background',
                subtitle: 'Pick a custom wallpaper for messaging screens',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 22,
                ),
                onTap: () => _pickBackground(ref),
              ),
              if (hasCustomBg)
                SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  iconBackgroundColor: Colors.grey.shade600,
                  title: 'Reset to default',
                  onTap: () async {
                    await ref
                        .read(chatBackgroundProvider.notifier)
                        .resetBackground();
                    Snack.show('Chat background reset');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
