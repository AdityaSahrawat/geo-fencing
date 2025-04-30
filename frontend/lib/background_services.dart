import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Entry point for background service
 final String localURL = "http://10.0.10.5:5000";
@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    final androidService = service as AndroidServiceInstance;

    // Listen for stop request
    androidService.on('stopService').listen((_) {
      androidService.stopSelf();
    });

    // Set foreground notification (required for Android)
    androidService.setForegroundNotificationInfo(
      title: 'Attendance Tracker',
      content: 'Tracking location in background.',
    );

    // Ensure permission for Android 13+
    await requestNotificationPermission();
  }

  // Initialize socket and location tracking
  await initializeSocket(service);

  return true; // Keep service running
}

// Request notification permission (Android 13+)
Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid && await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

// Initialize socket connection
Future<void> initializeSocket(ServiceInstance service) async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('email');
  final token = prefs.getString('token');
  const localURL = 'http://your-server-url';

  if (email == null || token == null) {
    print("❌ Missing email or token, stopping service.");
    service.stopSelf();
    return;
  }

  IO.Socket socket = IO.io(localURL, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

  // Connect and handle socket events
  socket.connect();

  socket.onConnect((_) {
    print("✅ Background Socket Connected");
    socket.emit('joinRoom', email);
  });

  // Listen for location requests
  socket.on('requestCoordinates', (data) async {
    if (data['students'].contains(email)) {
      print("📌 Location request received in background.");
      await sendLocation(socket, data, token);
    }
  });

  socket.onDisconnect((_) => print("❌ Socket Disconnected"));
}

// Send location to the server
Future<void> sendLocation(IO.Socket socket, dynamic data, String token) async {
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    print("❌ Location permission denied!");
    return;
  }

  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  try {
    final response = await http.post(
      Uri.parse('$localURL/api/attendance/send-coordinates'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'roomNo': data['roomNo'],
        'latitude': position.latitude,
        'longitude': position.longitude,
        'email': data['email'],
      }),
    );

    if (response.statusCode == 200) {
      print("✅ Location sent successfully!");
    } else {
      print("❌ Failed to send location: ${response.body}");
    }
  } catch (e) {
    print("❌ Error sending location: $e");
  }
}

// Initialize background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Ensure notification channel is created
  await createNotificationChannel();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'attendance_channel',
      initialNotificationTitle: 'Attendance Tracker',
      initialNotificationContent: 'Tracking location in background.',
    ),
    iosConfiguration: IosConfiguration(
      onBackground: onStart,
      onForeground: onStart,
    ),
  );

  await service.startService();
  print("🚀 Background service initialized and started");
}

// Create notification channel (for Android 8+)
Future<void> createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'attendance_channel',
    'Attendance Tracking',
    description: 'Tracks location in the background for attendance.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
