import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'models/alarm_model.dart';
import 'services/alarm_service.dart';

/// Перший екран додатку «Будильник»: поточний час, найближчий будильник
/// та список будильників з перемикачами. Усе працює по-справжньому:
/// будильники зберігаються і дзвонять у вказаний час, навіть коли
/// застосунок закритий.
class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  State<FirstScreen> createState() => _FirstScreenState();
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

  final _service = AlarmService.instance;

  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Без цих дозволів Android може не дати будильнику спрацювати.
    unawaited(_service.requestPermissions());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  /// Текст «Наступний будильник через …» для найближчого увімкненого.
  String? _nextAlarmText() {
    final next = _service.nextRing();
    if (next == null) return null;
    final diff = next.difference(_now);
    final totalMin = diff.inMinutes + (diff.inSeconds % 60 > 0 ? 1 : 0);
    final d = totalMin ~/ (24 * 60);
    final h = (totalMin % (24 * 60)) ~/ 60;
    final m = totalMin % 60;
    final parts = <String>[
      if (d > 0) '$d д',
      if (h > 0) '$h год',
      if (m > 0 || (d == 0 && h == 0)) '$m хв',
    ];
    return 'Наступний будильник через ${parts.join(' ')}';
  }

  Future<void> _openEditor([AlarmModel? existing]) async {
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AlarmEditor(existing: existing),
    );
    if (result == null) return;

    if (existing == null) {
      await _service.add(
        hour: result.time.hour,
        minute: result.time.minute,
        label: result.label,
        days: result.days,
      );
    } else {
      await _service.update(
        existing,
        hour: result.time.hour,
        minute: result.time.minute,
        label: result.label,
        days: result.days,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) => Column(
            children: [
              _buildHeader(_nextAlarmText()),
              Expanded(child: _buildAlarmList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
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
                Flexible(
                  child: Text(
                    nextText ?? 'Усі будильники вимкнені',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmList() {
    final alarms = _service.alarms;
    if (alarms.isEmpty) {
      return const Center(
        child: Text(
          'Поки що немає будильників',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: alarms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final alarm = alarms[i];
        return Dismissible(
          key: ValueKey(alarm.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _service.delete(alarm),
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
            onTap: () => _openEditor(alarm),
            onChanged: (v) => _service.setEnabled(alarm, v),
          ),
        );
      },
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.onTap,
    required this.onChanged,
  });

  final AlarmModel alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = alarm.enabled;
    final subtitle = alarm.label.isEmpty
        ? alarm.daysText
        : '${alarm.label} · ${alarm.daysText}';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: on ? 1 : 0.55,
      child: Material(
        color: _FirstScreenState._card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
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
                        alarm.timeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                  activeThumbColor: Colors.white,
                  activeTrackColor: _FirstScreenState._accent,
                  inactiveThumbColor: Colors.white54,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorResult {
  const _EditorResult(this.time, this.label, this.days);

  final TimeOfDay time;
  final String label;
  final Set<int> days;
}

/// Нижня панель створення/редагування будильника.
class _AlarmEditor extends StatefulWidget {
  const _AlarmEditor({this.existing});

  final AlarmModel? existing;

  @override
  State<_AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<_AlarmEditor> {
  late TimeOfDay _time;
  late Set<int> _days;
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _time = a == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: a.hour, minute: a.minute);
    _days = {...?a?.days};
    _label = TextEditingController(text: a?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _FirstScreenState._accent,
              surface: _FirstScreenState._card,
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final timeText =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: TextButton(
                onPressed: _pickTime,
                child: Text(
                  timeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _label,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Назва (необовʼязково)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Повтор',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(AlarmModel.shortDayNames[d - 1]),
                    selected: _days.contains(d),
                    showCheckmark: false,
                    selectedColor: _FirstScreenState._accent,
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white),
                    side: BorderSide.none,
                    onSelected: (v) => setState(() {
                      v ? _days.add(d) : _days.remove(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _days.isEmpty
                  ? 'Без повтору — спрацює один раз'
                  : 'Повторюється у вибрані дні',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Скасувати'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _EditorResult(_time, _label.text.trim(), {..._days}),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _FirstScreenState._accent,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Зберегти'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
