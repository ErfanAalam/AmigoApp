import 'package:flutter/material.dart';

/// A reusable search bar widget for list screens
/// 
/// This widget can be used in chat lists, group lists, or any other
/// list that needs search functionality with a consistent design.
class SearchableListBar extends StatelessWidget {
  /// The text controller for the search field
  final TextEditingController controller;
  
  /// The placeholder text shown in the search field
  final String hintText;
  
  /// Callback function called when the search text changes
  final void Function(String)? onChanged;
  
  /// Optional callback when clear button is pressed
  final VoidCallback? onClear;
  
  /// Whether to show the clear button (X icon) when there's text
  final bool showClearButton;

  const SearchableListBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.showClearButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: showClearButton && value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        controller.clear();
                        onClear?.call();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A complete searchable list layout widget that includes:
/// - The search bar at the top
/// - The filtered content below
/// 
/// This provides a consistent layout for all searchable lists.
class SearchableListLayout extends StatelessWidget {
  /// The search bar widget
  final Widget searchBar;
  
  /// The content to display (typically a list)
  final Widget content;
  
  /// Background color of the container (default: Colors.grey[50])
  final Color? backgroundColor;

  const SearchableListLayout({
    super.key,
    required this.searchBar,
    required this.content,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.grey[50],
      child: Column(
        children: [
          // Search Bar
          searchBar,
          
          // Content
          Expanded(child: content),
        ],
      ),
    );
  }
}

