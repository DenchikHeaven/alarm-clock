import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Перший екран додатку «Будильник»: поточний час, найближчий будильник
/// та список будильників з перемикачами.
class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  State<FirstScreen> createState() => _FirstScreenState();
}

class _AlarmItem {
  _AlarmItem({
    required this.time,
    required this.label,
    required this.days,
    this.enabled = true,
  });

  final TimeOfDay time;
  final String label;
  final String days;
  bool enabled;
}

class _FirstScreenState extends State<FirstScreen> {
  static const _bg = Color(0xFF0F1222);
  static const _card = Color(0xFF1A1E36);
  static const _accent = Color(0xFF7C83FF);
  static const _accentSoft = Color(0xFFB9BDFF);

  static const _weekdays = [
    'понеділок',
    'вівторок',
    'середа',
    'четвер',
    'пʼятниця',
    'субота',
    'неділя',
  ];
  static const _months = [
    'січня',
    'лютого',
    'березня',
    'квітня',
    'травня',
    'червня',
    'липня',
    'серпня',
    'вересня',
    'жовтня',
    'листопада',
    'грудня',
  ];

  late DateTime _now;
  Timer? _timer;

  final List<_AlarmItem> _alarms = [
    _AlarmItem(
      time: const TimeOfDay(hour: 6, minute: 30),
      label: 'Підйом',
      days: 'Пн – Пт',
    ),
    _AlarmItem(
      time: const TimeOfDay(hour: 8, minute: 0),
      label: 'Вихідні',
      days: 'Сб, Нд',
      enabled: false,
    ),
    _AlarmItem(
      time: const TimeOfDay(hour: 22, minute: 45),
      label: 'Лягати спати',
      days: 'Щодня',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _fmt(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// Текст «Наступний будильник через …» для найближчого увімкненого.
  String? _nextAlarmText() {
    Duration? best;
    for (final a in _alarms.where((a) => a.enabled)) {
      var target = DateTime(
        _now.year,
        _now.month,
        _now.day,
        a.time.hour,
        a.time.minute,
      );
      if (!target.isAfter(_now)) target = target.add(const Duration(days: 1));
      final diff = target.difference(_now);
      if (best == null || diff < best) best = diff;
    }
    if (best == null) return null;
    final h = best.inHours;
    final m = best.inMinutes % 60;
    if (h == 0) return 'Наступний будильник через $m хв';
    return 'Наступний будильник через $h год $m хв';
  }

  Future<void> _addAlarm() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _alarms.add(
        _AlarmItem(time: picked, label: 'Будильник', days: 'Щодня'),
      );
      _alarms.sort((a, b) =>
          (a.time.hour * 60 + a.time.minute) -
          (b.time.hour * 60 + b.time.minute));
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextText = _nextAlarmText();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(nextText),
            Expanded(child: _buildAlarmList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAlarm,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Додати'),
      ),
    );
  }

  Widget _buildHeader(String? nextText) {
    final date =
        '${_weekdays[_now.weekday - 1]}, ${_now.day} ${_months[_now.month - 1]}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F6B), Color(0xFF181C3D)],
        ),
      ),
      child: Column(
        children: [
          Text(
            date,
            style: const TextStyle(
              color: _accentSoft,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_two(_now.hour)}:${_two(_now.minute)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 76,
                  fontWeight: FontWeight.w200,
                  height: 1.1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _two(_now.second),
                style: const TextStyle(
                  color: _accentSoft,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  nextText == null
                      ? Icons.alarm_off_rounded
                      : Icons.alarm_rounded,
                  size: 18,
                  color: _accentSoft,
                ),
                const SizedBox(width: 8),
                Text(
                  nextText ?? 'Усі будильники вимкнені',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    if (_alarms.isEmpty) {
      return const Center(
        child: Text(
          'Поки що немає будильників',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _alarms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final alarm = _alarms[i];
        return Dismissible(
          key: ObjectKey(alarm),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => setState(() => _alarms.removeAt(i)),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFB3261E),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          child: _AlarmCard(
            alarm: alarm,
            timeText: _fmt(alarm.time),
            onChanged: (v) => setState(() => alarm.enabled = v),
          ),
        );
      },
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.timeText,
    required this.onChanged,
  });

  final _AlarmItem alarm;
  final String timeText;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = alarm.enabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: on ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _FirstScreenState._card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: on
                ? _FirstScreenState._accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alarm.label} · ${alarm.days}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: _FirstScreenState._accent,
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: Colors.white12,
            ),
          ],
        ),
      ),
    );
  }
}
