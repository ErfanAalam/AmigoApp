import 'dart:io';
import 'dart:ui' as ui;

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
                        ref.read(themeColorProvider.notifier).setTheme(theme);
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
    final bg = ref.watch(chatBackgroundProvider);
    final bgPath = bg.path;
    final hasCustomBg = bgPath != null && File(bgPath).existsSync();
    final imageProvider = hasCustomBg
        ? FileImage(File(bgPath)) as ImageProvider
        : const AssetImage('assets/images/chat_bg.jpg');

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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bg.blur)
                  ClipRect(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                        tileMode: TileMode.mirror,
                      ),
                      child: Transform.scale(
                        scale: 1.15,
                        child: Image(image: imageProvider, fit: BoxFit.cover),
                      ),
                    ),
                  )
                else
                  Image(image: imageProvider, fit: BoxFit.cover),
                if (bg.brightness < 1.0)
                  Container(
                    color: Colors.black.withOpacity(1.0 - bg.brightness),
                  ),
              ],
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
          SettingsCard(
            children: [
              _BrightnessSliderTile(
                brightness: bg.brightness,
                accent: themeColor.primary,
                onChanged: (value) => ref
                    .read(chatBackgroundProvider.notifier)
                    .setBrightness(value),
              ),
              _BlurToggleTile(
                enabled: bg.blur,
                accent: themeColor.primary,
                onChanged: (value) =>
                    ref.read(chatBackgroundProvider.notifier).setBlur(value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrightnessSliderTile extends StatelessWidget {
  final double brightness;
  final Color accent;
  final ValueChanged<double> onChanged;

  const _BrightnessSliderTile({
    required this.brightness,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (brightness * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.brightness_6_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Brightness',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: accent,
                    thumbColor: accent,
                    overlayColor: accent.withOpacity(0.15),
                    inactiveTrackColor: Colors.grey.shade300,
                  ),
                  child: Slider(
                    min: 0.3,
                    max: 1.0,
                    value: brightness.clamp(0.3, 1.0),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurToggleTile extends StatelessWidget {
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _BlurToggleTile({
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF5E5CE6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.blur_on_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Blur background',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
