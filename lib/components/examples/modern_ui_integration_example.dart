import 'package:flutter/material.dart';
import 'package:vevij/utils/app_colors.dart';
import 'package:vevij/utils/app_theme.dart';
import 'package:vevij/components/widgets/notification_popup_widget.dart';
import 'package:vevij/components/widgets/task_card_modern.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/services/notification_service.dart';

/// Example integration demonstrating modern UI components
///
/// This example shows how to:
/// 1. Use TaskCardModern instead of old card widget
/// 2. Set up NotificationService for popup notifications
/// 3. Apply modern theme and colors
///
/// Integration Steps:
///
/// Step 1: In main.dart, initialize notification service with navigator key
/// ```dart
/// class MyApp extends StatelessWidget {
///   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
///
///   @override
///   Widget build(BuildContext context) {
///     // Initialize notification service
///     NotificationService().setNavigatorKey(navigatorKey);
///
///     return MaterialApp(
///       navigatorKey: navigatorKey,
///       theme: AppTheme.lightTheme,
///       darkTheme: AppTheme.darkTheme,
///       // ... rest of app
///     );
///   }
/// }
/// ```
///
/// Step 2: Replace old task cards with TaskCardModern
/// ```dart
/// ListView.builder(
///   itemCount: tasks.length,
///   itemBuilder: (context, index) {
///     final task = tasks[index];
///     return TaskCardModern(
///       task: task,
///       showActions: true,
///       onTap: () => Navigator.push(
///         context,
///         MaterialPageRoute(
///           builder: (_) => TaskDetailsPage(task: task),
///         ),
///       ),
///       onComplete: () async {
///         await TaskService().updateTask(
///           task.id,
///           {'status': TaskStatus.completed.name},
///           by: currentUserId,
///         );
///       },
///       onEdit: () => Navigator.push(
///         context,
///         MaterialPageRoute(
///           builder: (_) => CreateTaskPage(taskToEdit: task),
///         ),
///       ),
///       onDelete: () => _showDeleteConfirmation(task),
///     );
///   },
/// )
/// ```
///
/// Step 3: Notifications will automatically trigger popups when tasks are:
/// - Assigned
/// - Updated
/// - Commented on
/// - Status changed
/// - Due date changed
///
/// The NotificationService automatically listens to the Firestore
/// notifications collection and displays popups using the
/// NotificationPopupManager.
///
/// Step 4: (Optional) Manually show a notification popup
/// ```dart
/// NotificationPopupManager.instance.show(
///   context: context,
///   title: 'Custom Notification',
///   message: 'This is a custom message',
///   type: NotificationType.general,
///   onTap: () => print('Notification tapped'),
///   actions: [
///     NotificationAction(
///       label: 'Action',
///       onPressed: () => print('Action pressed'),
///     ),
///   ],
/// );
/// ```

class ModernUIIntegrationExample extends StatelessWidget {
  const ModernUIIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Example: Modern styled container with glassmorphism
    return Scaffold(
      appBar: AppBar(
        title: Text('Modern UI Example'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example: Info card with glassmorphism
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing4),
              decoration: AppTheme.glassmorphicDecoration(
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integration Complete! 🎉',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    'Modern UI components are now available',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing6),

            // Example: Show notification button
            ElevatedButton.icon(
              onPressed: () {
                NotificationPopupManager.instance.show(
                  context: context,
                  title: 'Test Notification',
                  message: 'This is a demo notification popup!',
                  type: NotificationType.taskAssignment,
                  actions: [
                    NotificationAction(
                      label: 'View',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Action pressed!')),
                        );
                      },
                    ),
                  ],
                );
              },
              icon: Icon(Icons.notifications_active),
              label: Text('Show Test Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing6,
                  vertical: AppTheme.spacing3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
