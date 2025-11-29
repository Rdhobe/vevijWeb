import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:vevij/utils/app_colors.dart';
import 'package:vevij/utils/app_theme.dart';

/// Enum for notification types
enum NotificationType {
  taskAssignment,
  taskUpdate,
  taskComment,
  taskStatusChange,
  taskDueDateChange,
  taskDeletion,
  teamCreation,
  teamUpdate,
  teamMemberAdded,
  teamMemberRemoved,
  general,
}

/// Modern animated notification popup widget
class NotificationPopupWidget extends StatefulWidget {
  final String title;
  final String message;
  final NotificationType type;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final List<NotificationAction>? actions;
  final Duration duration;

  const NotificationPopupWidget({
    super.key,
    required this.title,
    required this.message,
    this.type = NotificationType.general,
    this.onTap,
    this.onDismiss,
    this.actions,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<NotificationPopupWidget> createState() =>
      _NotificationPopupWidgetState();
}

class _NotificationPopupWidgetState extends State<NotificationPopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _dismissProgress = 0;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      duration: AppTheme.normalAnimation,
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: AppTheme.bounceCurve),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Start slide-in animation
    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss?.call();
      Navigator.of(context).pop();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dismissProgress = (details.primaryDelta ?? 0) / -200;
      _dismissProgress = _dismissProgress.clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dismissProgress > 0.3) {
      _dismiss();
    } else {
      setState(() {
        _dismissProgress = 0;
      });
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.taskAssignment:
        return Icons.assignment_turned_in;
      case NotificationType.taskUpdate:
        return Icons.update;
      case NotificationType.taskComment:
        return Icons.comment;
      case NotificationType.taskStatusChange:
        return Icons.flag;
      case NotificationType.taskDueDateChange:
        return Icons.calendar_today;
      case NotificationType.taskDeletion:
        return Icons.delete;
      case NotificationType.teamCreation:
        return Icons.group_add;
      case NotificationType.teamUpdate:
        return Icons.group;
      case NotificationType.teamMemberAdded:
        return Icons.person_add;
      case NotificationType.teamMemberRemoved:
        return Icons.person_remove;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor() {
    switch (widget.type) {
      case NotificationType.taskAssignment:
      case NotificationType.teamCreation:
      case NotificationType.teamMemberAdded:
        return AppColors.success;
      case NotificationType.taskUpdate:
      case NotificationType.teamUpdate:
        return AppColors.info;
      case NotificationType.taskComment:
        return AppColors.accentCyan;
      case NotificationType.taskStatusChange:
        return AppColors.primary;
      case NotificationType.taskDueDateChange:
        return AppColors.warning;
      case NotificationType.taskDeletion:
      case NotificationType.teamMemberRemoved:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getColor();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing4),
          child: GestureDetector(
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            onTap: () {
              widget.onTap?.call();
              _dismiss();
            },
            child: Transform.translate(
              offset: Offset(0, -_dismissProgress * 100),
              child: Opacity(
                opacity: 1 - _dismissProgress,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.9),
                            color.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacing4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacing2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSmall,
                                      ),
                                    ),
                                    child: Icon(
                                      _getIcon(),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacing3),

                                  // Title and Message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppTheme.spacing1,
                                        ),
                                        Text(
                                          widget.message,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Close button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed: _dismiss,
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),

                              // Action buttons
                              if (widget.actions != null &&
                                  widget.actions!.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spacing3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: widget.actions!.map((action) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: AppTheme.spacing2,
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          action.onPressed();
                                          _dismiss();
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.white
                                              .withOpacity(0.2),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacing4,
                                            vertical: AppTheme.spacing2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSmall,
                                            ),
                                          ),
                                        ),
                                        child: Text(action.label),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],

                              // Progress indicator
                              const SizedBox(height: AppTheme.spacing2),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                                child: LinearProgressIndicator(
                                  value: 1 - (_dismissProgress),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.5),
                                  ),
                                  minHeight: 3,
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
          ),
        ),
      ),
    );
  }
}

/// Notification action button data class
class NotificationAction {
  final String label;
  final VoidCallback onPressed;

  const NotificationAction({required this.label, required this.onPressed});
}

/// Notification popup manager for displaying notifications
class NotificationPopupManager {
  static final NotificationPopupManager _instance =
      NotificationPopupManager._internal();
  factory NotificationPopupManager() => _instance;
  NotificationPopupManager._internal();

  static NotificationPopupManager get instance => _instance;

  OverlayEntry? _currentOverlay;

  /// Show notification popup
  void show({
    required BuildContext context,
    required String title,
    required String message,
    NotificationType type = NotificationType.general,
    VoidCallback? onTap,
    List<NotificationAction>? actions,
    Duration duration = const Duration(seconds: 5),
  }) {
    // Dismiss existing notification if any
    dismiss();

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: NotificationPopupWidget(
          title: title,
          message: message,
          type: type,
          onTap: onTap,
          onDismiss: () => dismiss(),
          actions: actions,
          duration: duration,
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Dismiss current notification
  void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}
