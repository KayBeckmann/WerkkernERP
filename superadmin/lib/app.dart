import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'login_screen.dart';

class SuperadminApp extends StatelessWidget {
  const SuperadminApp({super.key, required this.clientFactory});

  final WerkkernApiClient Function() clientFactory;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: brightness),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'WerkkernERP Plattform',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: LoginScreen(clientFactory: clientFactory),
    );
  }
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String describeError(Object e) => switch (e) {
      ApiException(:final message) => message,
      ApiUnreachable() => 'Server nicht erreichbar.',
      _ => 'Unerwarteter Fehler: $e',
    };
