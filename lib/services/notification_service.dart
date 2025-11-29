import 'package:vevij/components/imports.dart';
import 'package:vevij/components/widgets/notification_popup_widget.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Global navigation key for showing popup overlays
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Set the navigator key for showing popup notifications
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // Initialize notification service
  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get FCM token and save to user document
      String? token = await _firebaseMessaging.getToken(
        vapidKey:
            'BP04meoXQwoQDhHvT_E_TBVjcmhEUJCfBJKGcKDCA6F7k4ib9Y6YSj4JrJ1y4pxz1imzP-KvSA2gI_2XmO_cg7I', // ← Add your key here
      );
      if (token != null && _auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {'fcmToken': token, 'tokenUpdatedAt': FieldValue.serverTimestamp()},
        );
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) async {
        if (_auth.currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .update({
                'fcmToken': token,
                'tokenUpdatedAt': FieldValue.serverTimestamp(),
              });
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Handle app opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // Listen to new notifications in Firestore for popup display
      _listenToNotifications();
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Handling a foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'chat_channel',
          'Chat Notifications',
          channelDescription: 'Notifications for chat messages',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: false,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF1976D2),
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      platformChannelSpecifics,
      payload: _createNotificationPayload(message),
    );
  }

  // Create notification payload
  String _createNotificationPayload(RemoteMessage message) {
    Map<String, dynamic> payload = {
      'type': message.data['type'] ?? 'chat',
      'chatId': message.data['chatId'],
      'projectId': message.data['projectId'],
      'senderId': message.data['senderId'],
      'senderName': message.data['senderName'],
    };
    return payload.toString();
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse notificationResponse) {
    if (notificationResponse.payload != null) {
      _navigateToChat(notificationResponse.payload!);
    }
  }

  // Handle message tap from background/terminated
  void _handleMessageTap(RemoteMessage message) {
    String payload = _createNotificationPayload(message);
    _navigateToChat(payload);
  }

  // Navigate to appropriate chat screen
  void _navigateToChat(String payload) {
    // Parse payload and navigate to chat
    // This would need to be integrated with your app's navigation system
    print('Navigate to chat with payload: $payload');

    // Example navigation logic:
    /*
    if (payload.contains('personal_chat')) {
      Navigator.pushNamed(context, '/personal_chat', arguments: chatData);
    } else if (payload.contains('project_chat')) {
      Navigator.pushNamed(context, '/project_chat', arguments: projectData);
    }
    */
  }

  // Send push notification to specific user
  Future<void> sendNotificationToUser({
    required String receiverId,
    required String title,
    required String body,
    required String type,
    String? chatId,
    String? projectId,
    String? senderName,
  }) async {
    try {
      // Get receiver's FCM token
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();

      if (!userDoc.exists) return;

      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      String? fcmToken = userData?['fcmToken'];

      if (fcmToken == null) return;

      // Create notification data
      Map<String, dynamic> notificationData = {
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': '1',
        },
        'data': {
          'type': type,
          'senderId': _auth.currentUser?.uid ?? '',
          'senderName': senderName ?? 'Unknown',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      };

      if (chatId != null) notificationData['data']['chatId'] = chatId;
      if (projectId != null) notificationData['data']['projectId'] = projectId;

      // Store notification in Firestore (optional - for notification history)
      await _firestore.collection('notifications').add({
        'receiverId': receiverId,
        'senderId': _auth.currentUser?.uid,
        'title': title,
        'body': body,
        'type': type,
        'chatId': chatId,
        'projectId': projectId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Here you would call your backend service to send the FCM message
      // Since Flutter can't directly send FCM messages, this needs to be done via Cloud Functions

      print('Notification prepared for user: $receiverId');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification for personal chat message
  Future<void> sendPersonalChatNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await sendNotificationToUser(
      receiverId: receiverId,
      title: senderName,
      body: message,
      type: 'personal_chat',
      chatId: chatId,
      senderName: senderName,
    );
  }

  // Send notification for project chat message
  Future<void> sendProjectChatNotification({
    required List<String> receiverIds,
    required String senderName,
    required String message,
    required String projectId,
    required String projectName,
  }) async {
    for (String receiverId in receiverIds) {
      if (receiverId != _auth.currentUser?.uid) {
        // Don't send to sender
        await sendNotificationToUser(
          receiverId: receiverId,
          title: '$projectName - $senderName',
          body: message,
          type: 'project_chat',
          projectId: projectId,
          senderName: senderName,
        );
      }
    }
  }

  // Send notification for chat request
  Future<void> sendChatRequestNotification({
    required String receiverId,
    required String senderName,
  }) async {
    await sendNotificationToUser(
      receiverId: receiverId,
      title: 'New Chat Request',
      body: '$senderName wants to chat with you',
      type: 'chat_request',
      senderName: senderName,
    );
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    if (_auth.currentUser == null) return 0;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    if (_auth.currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();

      for (DocumentSnapshot doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get notification stream
  Stream<QuerySnapshot> getNotificationStream() {
    if (_auth.currentUser == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: _auth.currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Clear old notifications (older than 30 days)
  Future<void> clearOldNotifications() async {
    if (_auth.currentUser == null) return;

    try {
      DateTime thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      WriteBatch batch = _firestore.batch();

      for (DocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleared ${snapshot.docs.length} old notifications');
    } catch (e) {
      print('Error clearing old notifications: $e');
    }
  }

  // Update user's online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Listen to user's online status
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return false;
      Map<String, dynamic>? data = snapshot.data();
      return data?['isOnline'] ?? false;
    });
  }

  // Show in-app notification banner
  void showInAppNotification(
    BuildContext context,
    String title,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Handle view action
          },
        ),
      ),
    );
  }

  // ========== TASK MANAGEMENT NOTIFICATIONS ==========

  // Send notification when user is assigned to a task
  Future<void> sendTaskAssignmentNotification({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    String? assignedBy,
  }) async {
    for (String userId in userIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'New Task Assigned',
        'body': 'You have been assigned to task: $taskTitle',
        'taskId': taskId,
        'type': 'task_assignment',
        'assignedBy': assignedBy ?? _auth.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Send notification when task is updated
  Future<void> sendTaskUpdateNotification({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    required String updateType,
  }) async {
    for (String userId in userIds) {
      if (userId != _auth.currentUser?.uid) {
        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': 'Task Updated',
          'body': 'Task "$taskTitle" has been updated ($updateType)',
          'taskId': taskId,
          'type': 'task_update',
          'updatedBy': _auth.currentUser?.uid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Send notification for new task comment
  Future<void> sendTaskCommentNotification({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    required String commenterName,
    required String comment,
  }) async {
    for (String userId in userIds) {
      if (userId != _auth.currentUser?.uid) {
        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': 'New Comment on $taskTitle',
          'body': '$commenterName: $comment',
          'taskId': taskId,
          'type': 'task_comment',
          'commentedBy': _auth.currentUser?.uid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Send notification when task due date changes
  Future<void> sendTaskDueDateChangeNotification({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    required String newDueDate,
  }) async {
    for (String userId in userIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Due Date Updated',
        'body': 'Task "$taskTitle" due date has been changed to $newDueDate',
        'taskId': taskId,
        'type': 'task_due_date_change',
        'updatedBy': _auth.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Send notification when task status changes
  Future<void> sendTaskStatusChangeNotification({
    required List<String> userIds,
    required String taskTitle,
    required String taskId,
    required String newStatus,
  }) async {
    for (String userId in userIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Task Status Changed',
        'body': 'Task "$taskTitle" status changed to $newStatus',
        'taskId': taskId,
        'type': 'task_status_change',
        'updatedBy': _auth.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Send notification when task is deleted
  Future<void> sendTaskDeletionNotification({
    required List<String> userIds,
    required String taskTitle,
  }) async {
    for (String userId in userIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Task Deleted',
        'body': 'Task "$taskTitle" has been deleted',
        'type': 'task_deletion',
        'deletedBy': _auth.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ========== TEAM MANAGEMENT NOTIFICATIONS ==========

  // Send notification when team is created
  Future<void> sendTeamCreationNotification({
    required List<String> memberIds,
    required String teamName,
    required String teamId,
  }) async {
    for (String userId in memberIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Added to Team',
        'body': 'You have been added to team: $teamName',
        'teamId': teamId,
        'type': 'team_creation',
        'createdBy': _auth.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Send notification when member is added to team
  Future<void> sendTeamMemberAddedNotification({
    required List<String> existingMemberIds,
    required String newMemberName,
    required String teamName,
    required String teamId,
  }) async {
    for (String userId in existingMemberIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'New Team Member',
        'body': '$newMemberName has joined team: $teamName',
        'teamId': teamId,
        'type': 'team_member_added',
        'addedBy': _auth.currentUser?.uid,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Send notification when member is removed from team
  Future<void> sendTeamMemberRemovedNotification({
    required String removedUserId,
    required String teamName,
    required String teamId,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': removedUserId,
      'title': 'Removed from Team',
      'body': 'You have been removed from team: $teamName',
      'teamId': teamId,
      'type': 'team_member_removed',
      'removedBy': _auth.currentUser?.uid,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Send notification when team is updated
  Future<void> sendTeamUpdateNotification({
    required List<String> memberIds,
    required String teamName,
    required String teamId,
    required String updateType,
  }) async {
    for (String userId in memberIds) {
      if (userId != _auth.currentUser?.uid) {
        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': 'Team Updated',
          'body': 'Team "$teamName" has been updated ($updateType)',
          'teamId': teamId,
          'type': 'team_update',
          'updatedBy': _auth.currentUser?.uid,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // Listen to notifications and show popups
  void _listenToNotifications() {
    if (_auth.currentUser == null) return;

    _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                _showNotificationPopup(data, change.doc.id);
              }
            }
          }
        });
  }

  // Show notification popup
  void _showNotificationPopup(
    Map<String, dynamic> data,
    String notificationId,
  ) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      print('Cannot show notification popup: Navigator key not set');
      return;
    }

    final context = _navigatorKey!.currentContext!;
    final type = data['type'] as String?;
    final title = data['title'] as String? ?? 'New Notification';
    final body = data['body'] as String? ?? '';
    final taskId = data['taskId'] as String?;
    final teamId = data['teamId'] as String?;

    // Determine notification type
    NotificationType notificationType;
    switch (type) {
      case 'task_assignment':
        notificationType = NotificationType.taskAssignment;
        break;
      case 'task_update':
        notificationType = NotificationType.taskUpdate;
        break;
      case 'task_comment':
        notificationType = NotificationType.taskComment;
        break;
      case 'task_status_change':
        notificationType = NotificationType.taskStatusChange;
        break;
      case 'task_due_date_change':
        notificationType = NotificationType.taskDueDateChange;
        break;
      case 'task_deletion':
        notificationType = NotificationType.taskDeletion;
        break;
      case 'team_creation':
        notificationType = NotificationType.teamCreation;
        break;
      case 'team_update':
        notificationType = NotificationType.teamUpdate;
        break;
      case 'team_member_added':
        notificationType = NotificationType.teamMemberAdded;
        break;
      case 'team_member_removed':
        notificationType = NotificationType.teamMemberRemoved;
        break;
      default:
        notificationType = NotificationType.general;
    }

    // Show popup
    NotificationPopupManager.instance.show(
      context: context,
      title: title,
      message: body,
      type: notificationType,
      onTap: () {
        // Navigate to task or team details
        if (taskId != null) {
          // TODO: Navigate to task details
          print('Navigate to task: $taskId');
        } else if (teamId != null) {
          // TODO: Navigate to team details
          print('Navigate to team: $teamId');
        }

        // Mark as read
        markNotificationAsRead(notificationId);
      },
      actions: [
        if (taskId != null)
          NotificationAction(
            label: 'View Task',
            onPressed: () {
              print('View task: $taskId');
              markNotificationAsRead(notificationId);
            },
          ),
        if (teamId != null)
          NotificationAction(
            label: 'View Team',
            onPressed: () {
              print('View team: $teamId');
              markNotificationAsRead(notificationId);
            },
          ),
      ],
    );
  }

  // Dispose
  void dispose() {
    // Clean up any subscriptions if needed
  }
}
