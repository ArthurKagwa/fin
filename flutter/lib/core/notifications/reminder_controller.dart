import 'package:fintrack/core/notifications/notification_service.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminder_controller.g.dart';

@riverpod
class ReminderController extends _$ReminderController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> setReminder({required int hour, required int minute}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(notificationServiceProvider);
      final granted = await service.requestPermission();
      if (!granted) {
        throw StateError('Notifications are turned off for FinTrack in system settings.');
      }
      await service.scheduleDaily(hour: hour, minute: minute);
      await ref.read(profileRepositoryProvider).setReminder(hour: hour, minute: minute);
    });
  }

  Future<void> clearReminder() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(notificationServiceProvider).cancel();
      await ref.read(profileRepositoryProvider).setReminder(hour: null, minute: null);
    });
  }
}
