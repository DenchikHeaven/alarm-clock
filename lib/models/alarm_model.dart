/// Будильник у збереженому вигляді (те, що бачить і редагує користувач).
class AlarmModel {
  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    Set<int>? days,
    this.enabled = true,
    this.onceAt,
  }) : days = days ?? <int>{};

  static const shortDayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

  /// Унікальний номер (>= 1). З нього будуються id у пакеті `alarm`.
  final int id;
  int hour;
  int minute;
  String label;

  /// Дні повтору: DateTime.monday (1) … DateTime.sunday (7).
  /// Порожньо — будильник спрацює один раз.
  Set<int> days;
  bool enabled;

  /// Для одноразового будильника — момент, на який його заплановано.
  DateTime? onceAt;

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get daysText {
    if (days.isEmpty) return 'Один раз';
    if (days.length == 7) return 'Щодня';
    if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) {
      return 'Пн – Пт';
    }
    if (days.length == 2 && days.containsAll({6, 7})) return 'Сб, Нд';
    final sorted = days.toList()..sort();
    return sorted.map((d) => shortDayNames[d - 1]).join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'days': days.toList()..sort(),
        'enabled': enabled,
        'onceAt': onceAt?.toIso8601String(),
      };

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>?;
    final rawOnce = json['onceAt'] as String?;
    return AlarmModel(
      id: json['id'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      label: (json['label'] as String?) ?? '',
      days: rawDays == null
          ? <int>{}
          : rawDays.map((e) => e as int).toSet(),
      enabled: (json['enabled'] as bool?) ?? true,
      onceAt: rawOnce == null ? null : DateTime.parse(rawOnce),
    );
  }
}
