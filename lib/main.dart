import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'first_screen.dart';
import 'ring_screen.dart';
import 'services/alarm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _ringSub;
  int? _showingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Коли будь-який будильник починає дзвонити — показуємо екран дзвінка.
    _ringSub = Alarm.ringing.listen((set) => _onRing(set.alarms.toList()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AlarmService.instance.sync());
    }
  }

  void _onRing(List<AlarmSettings> ringing) {
    if (ringing.isEmpty || _showingId != null) return;
    final alarm = ringing.first;
    _showingId = alarm.id;

    void push() {
      final nav = navigatorKey.currentState;
      if (nav == null) {
        // Застосунок щойно стартував — навігатор ще не готовий.
        WidgetsBinding.instance.addPostFrameCallback((_) => push());
        return;
      }
      nav
          .push(MaterialPageRoute<void>(
            builder: (_) => RingScreen(alarm: alarm),
          ))
          .then((_) {
        _showingId = null;
        unawaited(AlarmService.instance.sync());
      });
    }

    push();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Будильник',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C83FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const FirstScreen(),
    );
  }
}
