import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable stylised search bar widget.
/// Used on the Home, Map and Search screens.
class SearchBarWidget extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    this.hint = 'Search room, lab or office...',
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        readOnly: widget.readOnly,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        style: const TextStyle(
          fontSize: 15,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
            size: 22,
          ),
          suffixIcon: widget.readOnly
              ? const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: AppTheme.cardSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
