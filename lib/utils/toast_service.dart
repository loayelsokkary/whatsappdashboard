import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/vivid_theme.dart';

enum ToastType { success, error, warning, info }

class VividToast {
  static final List<_ToastEntry> _activeToasts = [];
  static const int _maxVisible = 3;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? action,
    String? actionLabel,
  }) {
    final overlay = Overlay.of(context);
    final entry = _ToastEntry();

    entry.overlayEntry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        title: title,
        duration: duration,
        action: action,
        actionLabel: actionLabel,
        onDismiss: () => _removeToast(entry),
        bottomOffset: _calculateOffset(entry),
      ),
    );

    _activeToasts.add(entry);

    // Dismiss oldest if over max
    while (_activeToasts.length > _maxVisible) {
      final oldest = _activeToasts.first;
      _removeToast(oldest);
    }

    overlay.insert(entry.overlayEntry!);
    _repositionAll();
  }

  static double _calculateOffset(_ToastEntry entry) {
    final index = _activeToasts.indexOf(entry);
    if (index < 0) return 0;
    return 16.0 + (index * 76.0);
  }

  static void _repositionAll() {
    for (final entry in _activeToasts) {
      entry.overlayEntry?.markNeedsBuild();
    }
  }

  static void _removeToast(_ToastEntry entry) {
    if (_activeToasts.remove(entry)) {
      entry.overlayEntry?.remove();
      entry.overlayEntry = null;
      _repositionAll();
    }
  }
}

class _ToastEntry {
  OverlayEntry? overlayEntry;
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final String? title;
  final Duration duration;
  final VoidCallback? action;
  final String? actionLabel;
  final VoidCallback onDismiss;
  final double bottomOffset;

  const _ToastWidget({
    required this.message,
    required this.type,
    this.title,
    required this.duration,
    this.action,
    this.actionLabel,
    required this.onDismiss,
    required this.bottomOffset,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoHideTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    _startAutoHide();
  }

  void _startAutoHide() {
    _autoHideTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _autoHideTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _typeColor() {
    switch (widget.type) {
      case ToastType.success:
        return VividColors.statusSuccess;
      case ToastType.error:
        return VividColors.statusUrgent;
      case ToastType.warning:
        return VividColors.statusWarning;
      case ToastType.info:
        return VividColors.cyan;
    }
  }

  IconData _typeIcon() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning_amber;
      case ToastType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = Theme.of(context).extension<VividColorScheme>();
    final color = _typeColor();
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth < 600 ? screenWidth - 32 : 420.0;

    return Positioned(
      bottom: widget.bottomOffset,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 100) {
                  _dismiss();
                }
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: vc?.surface ?? const Color(0xFF050520),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: color, width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _typeIcon(),
                          color: color,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.title != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    widget.title!,
                                    style: TextStyle(
                                      color: vc?.textPrimary ?? Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: vc?.textSecondary ?? Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.action != null &&
                            widget.actionLabel != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              widget.action!();
                              _dismiss();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: color,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: vc?.textSecondary ?? Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
