import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestBGService {
  static final TestBGService _instance = TestBGService._internal();
  factory TestBGService() => _instance;
  TestBGService._internal();

  Future<void> initializeService() async {
    print(
      "--------------------------------------------------------------------------------",
    );
    print("background initialize Service called");
    print(
      "--------------------------------------------------------------------------------",
    );

    final service = FlutterBackgroundService();

    /// ===================================================================================
    /// Not important, just for demo/showcase
    /// ===================================================================================
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.max, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('launch_background'),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    /// ===================================================================================
    /// ===================================================================================

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,

        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'AWESOME SERVICE',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        // onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    // DartPluginRegistrant.ensureInitialized();

    // For flutter prior to version 3.0.0
    // We have to register the plugin manually

    // SharedPreferences preferences = await SharedPreferences.getInstance();
    // await preferences.setString("hello", "world");

    /// OPTIONAL when use custom notification
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      print(
        "--------------------------------------------------------------------------------",
      );
      print("setAsForegroundService ");
      print(
        "--------------------------------------------------------------------------------",
      );

      // Set initial notification info immediately
      service.setForegroundNotificationInfo(
        title: "AWESOME SERVICE",
        content: "Initializing",
      );

      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // bring to foreground
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          /// OPTIONAL for use custom notification
          /// the notification id must be equals with AndroidConfiguration when you call configure() method.
          flutterLocalNotificationsPlugin.show(
            888,
            'COOL SERVICE',
            'Awesome ${DateTime.now()}',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'my_foreground',
                'MY FOREGROUND SERVICE',
                icon: 'launch_background',
                ongoing: true,
              ),
            ),
          );

          // if you don't using custom notification, uncomment this
          service.setForegroundNotificationInfo(
            title: "My App Service",
            content: "Updated at ${DateTime.now()}",
          );
        }
      }

      /// /// you can see this log in logcat
      /// debugPrint('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
      ///
      /// // test using external plugin
      /// final deviceInfo = DeviceInfoPlugin();
      /// String? device;
      /// if (Platform.isAndroid) {
      ///   final androidInfo = await deviceInfo.androidInfo;
      ///   device = androidInfo.model;
      /// } else if (Platform.isIOS) {
      ///   final iosInfo = await deviceInfo.iosInfo;
      ///   device = iosInfo.model;
      /// }
      ///
      /// service.invoke('update', {
      ///   "current_date": DateTime.now().toIso8601String(),
      ///   "device": device,
      /// });
    });
  }
}
