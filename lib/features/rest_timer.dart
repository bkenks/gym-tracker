import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../core/format.dart' show formatDuration;

class RestTimerState {
  const RestTimerState({
    this.totalSeconds = 0,
    this.remainingSeconds = 0,
    this.running = false,
  });

  final int totalSeconds;
  final int remainingSeconds;
  final bool running;

  bool get active => running || remainingSeconds > 0;

  RestTimerState copyWith({int? totalSeconds, int? remainingSeconds, bool? running}) =>
      RestTimerState(
        totalSeconds: totalSeconds ?? this.totalSeconds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        running: running ?? this.running,
      );
}

final restTimerProvider =
    NotifierProvider<RestTimerNotifier, RestTimerState>(RestTimerNotifier.new);

class RestTimerNotifier extends Notifier<RestTimerState> {
  Timer? _ticker;
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;

  @override
  RestTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _cancelNotification();
    });
    return const RestTimerState();
  }

  Future<void> start(int seconds) async {
    _ticker?.cancel();
    state = RestTimerState(totalSeconds: seconds, remainingSeconds: seconds, running: true);
    await _ensureNotifications();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(remainingSeconds: 0, running: false);
        _showFinishedNotification();
      } else {
        state = state.copyWith(remainingSeconds: next);
      }
    });
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(running: false);
  }

  void resume() {
    if (state.remainingSeconds > 0 && !state.running) {
      start(state.remainingSeconds);
    }
  }

  void stop() {
    _ticker?.cancel();
    _cancelNotification();
    state = const RestTimerState();
  }

  void addTime(int seconds) {
    if (!state.active) return;
    final next = state.remainingSeconds + seconds;
    state = state.copyWith(remainingSeconds: next, totalSeconds: state.totalSeconds + seconds);
  }

  Future<void> _ensureNotifications() async {
    if (_notificationsReady) return;
    // Local notifications are only supported on mobile platforms.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      try {
        await _notifications.initialize(
          settings: const InitializationSettings(
            iOS: DarwinInitializationSettings(),
            macOS: DarwinInitializationSettings(),
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            linux: LinuxInitializationSettings(defaultActionName: 'Open app'),
          ),
        );
        _notificationsReady = true;
        // Request permission on Apple platforms (no-op elsewhere).
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true);
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          await _notifications
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true);
        }
      } catch (e) {
        debugPrint('Notifications unavailable: $e');
      }
    }
  }

  Future<void> _showFinishedNotification() async {
    if (!_notificationsReady) return;
    try {
      await _notifications.show(
        id: 0,
        title: 'Rest over',
        body: 'Time for your next set!',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
          android: AndroidNotificationDetails(
            'rest_timer',
            'Rest Timer',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> _cancelNotification() async {
    if (!_notificationsReady) return;
    try {
      await _notifications.cancel(id: 0);
    } catch (_) {}
  }
}
