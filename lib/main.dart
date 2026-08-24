import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const DukanEdgeApp(),
    ),
  );
}
