import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm_model.dart';

/// Зберігає будильники та планує їх у системі через пакет `alarm`
/// (на Android — точні системні будильники + foreground-сервіс, тож дзвонить
/// і при закритому застосунку).
///
/// Для кожного будильника наперед планується кілька найближчих спрацювань
/// (14 днів на Android, 7 на iOS), щоб повторювані будильники працювали,
/// навіть якщо застосунок довго не відкривали.
///
/// Схема id у пакеті `alarm`: `id = alarmId * 16 + slot`.
///  * slot 0..14 — спрацювання за датою (номер дня % 15);
///  * slot 15 — відкладений сигнал (snooze).
class AlarmService extends ChangeNotifier {
  AlarmService._();

  static final AlarmService instance = AlarmService._();

  static const _prefsKey = 'alarms_v1';
  static const _nextIdKey = 'alarms_next_id_v1';
  static const _daySlots = 15;
  static const _snoozeSlot = 15;
  static const _idStride = 16;

  /// На скільки хвилин відкладає кнопка «Відкласти».
  static const snoozeMinutes = 5;

  final List<AlarmModel> alarms = [];

  bool _syncing = false;
  bool _syncAgain = false;

  // ---------------------------------------------------------------- init

  Future<void> init() async {
    await Alarm.init();
    await _load();
    // Поновлюємо системні будильники (довантажуємо наступні спрацювання).
    unawaited(sync());
  }

  /// Дозволи, без яких будильник не спрацює надійно (Android).
  /// На iOS дозвіл на сповіщення запитується в AppDelegate.
  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
      if (!await Permission.scheduleExactAlarm.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }

  // ------------------------------------------------------------- storage

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    alarms.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        alarms.addAll(
          list.map((e) => AlarmModel.fromJson(e as Map<String, dynamic>)),
        );
      } catch (e) {
        debugPrint('Failed to read saved alarms: $e');
      }
    }
    _sortAlarms();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(alarms.map((a) => a.toJson()).toList()),
    );
  }

  void _sortAlarms() {
    alarms.sort(
      (a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute),
    );
  }

  // ------------------------------------------------------------ user API

  Future<void> add({
    required int hour,
    required int minute,
    required String label,
    required Set<int> days,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = (prefs.getInt(_nextIdKey) ?? 0) + 1;
    await prefs.setInt(_nextIdKey, id);

    final alarm = AlarmModel(
      id: id,
      hour: hour,
      minute: minute,
      label: label,
      days: days,
      enabled: true,
      onceAt: days.isEmpty ? _nextTimeOfDay(hour, minute) : null,
    );
    alarms.add(alarm);
    _sortAlarms();
    notifyListeners();
    await _save();
    await sync();
  }

  Future<void> update(
    AlarmModel alarm, {
    required int hour,
    required int minute,
    required String label,
    required Set<int> days,
  }) async {
    alarm
      ..hour = hour
      ..minute = minute
      ..label = label
      ..days = days
      ..enabled = true
      ..onceAt = days.isEmpty ? _nextTimeOfDay(hour, minute) : null;
    _sortAlarms();
    notifyListeners();
    await _cancelAllFor(alarm.id);
    await _save();
    await sync();
  }

  Future<void> setEnabled(AlarmModel alarm, bool value) async {
    alarm.enabled = value;
    alarm.onceAt =
        (value && alarm.days.isEmpty) ? _nextTimeOfDay(alarm.hour, alarm.minute) : null;
    notifyListeners();
    await _cancelAllFor(alarm.id);
    await _save();
    await sync();
  }

  Future<void> delete(AlarmModel alarm) async {
    alarms.remove(alarm);
    notifyListeners();
    await _cancelAllFor(alarm.id);
    await _save();
  }

  /// Найближче спрацювання серед усіх увімкнених будильників.
  DateTime? nextRing() {
    final now = DateTime.now();
    DateTime? best;
    for (final a in alarms) {
      for (final dt in occurrences(a, now)) {
        if (best == null || dt.isBefore(best)) best = dt;
      }
    }
    return best;
  }

  // ------------------------------------------------------ ringing actions

  /// Зупинити дзвінок.
  Future<void> stop(AlarmSettings ringing) async {
    await Alarm.stop(ringing.id);
    await sync();
  }

  /// Відкласти дзвінок на [snoozeMinutes] хвилин.
  Future<void> snooze(AlarmSettings ringing) async {
    final snoozeId = (ringing.id ~/ _idStride) * _idStride + _snoozeSlot;
    final at = DateTime.now().add(const Duration(minutes: snoozeMinutes));
    await Alarm.stop(ringing.id);
    try {
      await Alarm.set(
        alarmSettings: ringing.copyWith(id: snoozeId, dateTime: at),
      );
    } catch (e) {
      debugPrint('Snooze failed: $e');
    }
    await sync();
  }

  // ---------------------------------------------------------------- sync

  /// Приводить заплановані системні будильники у відповідність до списку.
  /// Безпечно викликати скільки завгодно разів.
  Future<void> sync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _syncOnce();
      } while (_syncAgain);
    } catch (e, st) {
      debugPrint('Alarm sync failed: $e\n$st');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    final now = DateTime.now();
    var changed = false;

    // Одноразові будильники, час яких минув, вимикаємо.
    for (final a in alarms) {
      if (a.enabled && a.days.isEmpty) {
        final at = a.onceAt;
        if (at == null || !at.isAfter(now)) {
          a.enabled = false;
          a.onceAt = null;
          changed = true;
        }
      }
    }

    final existing = {
      for (final s in await Alarm.getAlarms()) s.id: s,
    };
    final knownIds = alarms.map((a) => a.id).toSet();

    final wanted = <int, DateTime>{};
    final owners = <int, AlarmModel>{};
    for (final a in alarms) {
      for (final dt in occurrences(a, now)) {
        final id = _idFor(a.id, dt);
        wanted[id] = dt;
        owners[id] = a;
      }
    }

    // Прибираємо зайве.
    for (final id in existing.keys) {
      final isSnooze = id % _idStride == _snoozeSlot;
      if (isSnooze) {
        if (knownIds.contains(id ~/ _idStride)) continue;
      } else if (wanted.containsKey(id)) {
        continue;
      }
      if (await Alarm.isRinging(id)) continue;
      await Alarm.stop(id);
    }

    // Додаємо відсутнє або змінене.
    for (final entry in wanted.entries) {
      final current = existing[entry.key];
      if (current != null &&
          current.dateTime.difference(entry.value).abs() <
              const Duration(seconds: 1)) {
        continue;
      }
      if (await Alarm.isRinging(entry.key)) continue;
      try {
        await Alarm.set(
          alarmSettings: _settingsFor(entry.key, entry.value, owners[entry.key]!),
        );
      } catch (e) {
        debugPrint('Alarm.set failed for ${entry.key}: $e');
      }
    }

    if (changed) await _save();
    notifyListeners();
  }

  Future<void> _cancelAllFor(int alarmId) async {
    for (final s in await Alarm.getAlarms()) {
      if (s.id ~/ _idStride != alarmId) continue;
      if (await Alarm.isRinging(s.id)) continue;
      await Alarm.stop(s.id);
    }
  }

  // ------------------------------------------------------------- helpers

  /// Найближчі спрацювання будильника, які ще попереду.
  @visibleForTesting
  List<DateTime> occurrences(AlarmModel a, DateTime now, {int? windowDays}) {
    if (!a.enabled) return const [];
    if (a.days.isEmpty) {
      final at = a.onceAt;
      return (at != null && at.isAfter(now)) ? [at] : const [];
    }
    final window = windowDays ?? (Platform.isIOS ? 7 : 14);
    final result = <DateTime>[];
    for (var i = 0; i < window; i++) {
      final dt = DateTime(now.year, now.month, now.day + i, a.hour, a.minute);
      if (a.days.contains(dt.weekday) && dt.isAfter(now)) result.add(dt);
    }
    return result;
  }

  @visibleForTesting
  int idFor(int alarmId, DateTime dt) => _idFor(alarmId, dt);

  int _idFor(int alarmId, DateTime dt) {
    final epochDay = DateTime.utc(dt.year, dt.month, dt.day)
        .difference(DateTime.utc(2020))
        .inDays;
    return alarmId * _idStride + epochDay % _daySlots;
  }

  DateTime _nextTimeOfDay(int hour, int minute) {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + 1, hour, minute);
    return at;
  }

  AlarmSettings _settingsFor(int id, DateTime at, AlarmModel a) {
    return AlarmSettings(
      id: id,
      dateTime: at,
      // null — стандартний звук будильника на телефоні.
      assetAudioPath: null,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
      androidStopAlarmOnTermination: false,
      volumeSettings: VolumeSettings.fade(
        volume: 0.9,
        fadeDuration: const Duration(seconds: 8),
      ),
      notificationSettings: NotificationSettings(
        title: a.label.isEmpty ? 'Будильник' : a.label,
        body: a.timeText,
        stopButton: 'Вимкнути',
      ),
    );
  }
}
