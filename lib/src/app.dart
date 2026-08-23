import 'package:flutter/material.dart';

import 'controllers/app_scope.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

class AutivraApp extends StatelessWidget {
  const AutivraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final seed = Color(controller.accentColorValue);
    final background = controller.backgroundColorValue == 0
        ? null
        : Color(controller.backgroundColorValue);
    final card = controller.cardColorValue == 0
        ? null
        : Color(controller.cardColorValue);
    final text = controller.textColorValue == 0
        ? null
        : Color(controller.textColorValue);
    return MaterialApp(
      title: 'SupeSlam',
      debugShowCheckedModeBanner: false,
      theme: buildAutivraTheme(
        Brightness.light,
        seed: seed,
        backgroundColor: background,
        cardColor: card,
        textColor: text,
        fontFamily: controller.fontFamily,
      ),
      darkTheme: buildAutivraTheme(
        Brightness.dark,
        seed: seed,
        backgroundColor: background,
        cardColor: card,
        textColor: text,
        fontFamily: controller.fontFamily,
      ),
      themeMode: controller.themeMode,
      builder: (context, child) => applyAutivraTextScale(
        context,
        child,
        controller.fontScale,
      ),
      home: const HomeShell(),
    );
  }
}
