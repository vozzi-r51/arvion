import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  static const List<Color> _themeColors = [
    Color(0xFF00695C), // Teal (Default)
    Color(0xFF1565C0), // Blue
    Color(0xFF2E7D32), // Green
    Color(0xFFC62828), // Red
    Color(0xFF6A1B9A), // Purple
    Color(0xFFAD1457), // Pink
    Color(0xFFEF6C00), // Orange
    Color(0xFF37474F), // Blue Grey
    Color(0xFF000000), // Black
    Color(0xFF5D4037), // Brown
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Theme Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Choose Primary Color',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _themeColors.length,
            itemBuilder: (ctx, i) {
              final color = _themeColors[i];
              final isSelected = themeProvider.primaryColor.value == color.value;

              return GestureDetector(
                onTap: () => themeProvider.setPrimaryColor(color),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.amber, width: 3)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Theme Mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (v) => themeProvider.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light Mode'),
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (v) => themeProvider.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark Mode'),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (v) => themeProvider.setThemeMode(v!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
