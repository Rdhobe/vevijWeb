import 'package:vevij/components/imports.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/team_service.dart';
import 'package:vevij/services/report_service.dart';
import 'package:vevij/services/user_service.dart';
import 'package:vevij/services/user_team_role_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // print("🔥 Handling a background message: ${message.messageId}");
  // print("Background message data: ${message.data}");

  if (message.notification != null) {
    // print("Background notification title: ${message.notification!.title}");
    // print("Background notification body: ${message.notification!.body}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Firebase web config (from Firebase Console → Project Settings → Web App)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBoFrLWpQTUrHw-wjOb3_lp5PTyDsxb7nw",
        authDomain: "vevij-16299.firebaseapp.com",
        projectId: "vevij-16299",
        storageBucket: "vevij-16299.firebasestorage.app",
        messagingSenderId: "566517432772",
        appId: "1:566517432772:web:57838836a81599ed206491",
        measurementId: "G-CK32FGGLVP",
      ),
    );
  } else {
    // Initialize default native Firebase but do not register background handlers in a web-first project
    await Firebase.initializeApp();
    // Only initialize messaging on mobile platforms
    await _initializeFirebaseMessaging();
  }

  runApp(const MyApp());
}

Future<void> _initializeFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permissions for iOS
  // NotificationSettings settings = await messaging.requestPermission(
  //   alert: true,
  //   announcement: false,
  //   badge: true,
  //   carPlay: false,
  //   criticalAlert: false,
  //   provisional: false,
  //   sound: true,
  // );

  // print('📱 User granted permission: ${settings.authorizationStatus}');

  // Get FCM token
  // String? token = await messaging.getToken();
  // print('📋 FCM Token: $token');

  // Handle token refresh
  messaging.onTokenRefresh.listen((newToken) {
    // print('🔄 FCM Token refreshed: $newToken');
    // You should save this new token to Firestore
    // _saveFCMTokenToFirestore(newToken);
  });

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // print('🎯 Got a message whilst in the foreground!');
    // print('Message data: ${message.data}');

    if (message.notification != null) {
      // print('📨 Message also contained a notification: ${message.notification!.title}');
      // print('📝 Notification body: ${message.notification!.body}');

      // Show a local notification or update UI
      _showForegroundNotification(message);
    }
  });

  // Handle notification taps when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    // print('🚀 A new onMessageOpenedApp event was published!');
    // print('Message data: ${message.data}');

    // Navigate to specific screen based on notification data
    _handleNotificationTap(message);
  });

  // Check if app was opened from a terminated state by tapping notification
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    // print('🎯 App opened from terminated state via notification');
    _handleNotificationTap(initialMessage);
  }
}

void _showForegroundNotification(RemoteMessage message) {
  // You can show a local notification here or update your UI
  // For example, show a snackbar or dialog
  // print('🔔 Showing foreground notification: ${message.notification?.title}');

  // If you want to show system notification even in foreground,
  // you can use flutter_local_notifications package
}

void _handleNotificationTap(RemoteMessage message) {
  // // Handle navigation based on notification data
  // print('🎯 Handling notification tap');
  // print('Chat ID: ${message.data['chatId']}');
  // print('Chat Type: ${message.data['chatType']}');
  // print('Sender ID: ${message.data['senderId']}');

  // You can navigate to specific chat screen here
  // For example:
  // Navigator.pushNamed(context, '/chat', arguments: {
  //   'chatId': message.data['chatId'],
  //   'chatType': message.data['chatType'],
  // });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notification service for web and mobile
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  Future<String?> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Initialize auth service
      AuthService().initialize();

      // Check if session is valid
      final isSessionValid = await AuthService().isSessionValid();

      if (isSessionValid) {
        // Get cached user data
        final userData = await AuthService().getCachedUserData();
        return userData['userRole'];
      }

      return null;
    } catch (e) {
      print('Error checking login status: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoticeProvider()),
        Provider(create: (context) => AuthService()),
        Provider<TaskService>(create: (_) => TaskService()),
        Provider<ReportService>(create: (_) => ReportService()),
        Provider<TeamService>(
          // Add TeamService provider
          create: (_) => TeamService(),
        ),
        Provider<UserService>(
          // Add UserService provider
          create: (_) => UserService(),
        ),
        Provider(create: (_) => UserTeamRoleService()),
        Provider(
          create: (_) => NotificationService(),
        ), // Add NotificationService provider
      ],
      child: MaterialApp(
        title: 'VeVji',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            primary: Colors.deepPurple,
            secondary: Colors.amberAccent,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white38,
              foregroundColor: Colors.deepPurple,
              shadowColor: Colors.greenAccent,
              elevation: 1,
            ),
          ),
          textTheme: TextTheme(
            bodySmall: TextStyle(
              color: Colors.deepPurple.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            headlineMedium: TextStyle(
              color: Colors.deepPurple.shade900,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            shadowColor: Colors.greenAccent,
            iconTheme: const IconThemeData(color: Colors.deepPurple),
            titleSpacing: 8.0,
            elevation: 4.0,
            actionsIconTheme: IconThemeData(color: Colors.deepPurple),
            titleTextStyle: TextStyle(
              color: Colors.deepPurple,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
          fontFamily: 'Lato',
        ),
        debugShowCheckedModeBanner: false,
        home: FutureBuilder<String?>(
          future: _checkLoginStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return const IntroPage();
            }
            return const IntroPage();
          },
        ),
        routes: {
          '/login': (context) => const LoginPage(),
          '/intro': (context) => const IntroPage(),
          '/empprofile': (context) => const EmpProfilePage(),
          '/layout': (context) => const EmployeeLayout(),
        },
      ),
    );
  }
}
