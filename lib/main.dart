import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Disable runtime fetching of fonts to ensure 100% offline operation.
  // The app now uses fontFamily declarations in AppTheme which look for
  // bundled assets in the 'assets/fonts' directory.
  GoogleFonts.config.allowRuntimeFetching = false;
  
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
