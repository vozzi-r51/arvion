import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

class AppRadius {
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double max = 999.0;
  
  static BorderRadius get small => BorderRadius.circular(s);
  static BorderRadius get medium => BorderRadius.circular(m);
  static BorderRadius get large => BorderRadius.circular(l);
  static BorderRadius get xLarge => BorderRadius.circular(xl);
}

class AppElevation {
  static const double none = 0.0;
  static const double low = 2.0;
  static const double medium = 4.0;
  static const double high = 8.0;
}

class AppTypography {
  // Using standard Material 3 naming conventions
  static TextStyle displayLarge(BuildContext context) => Theme.of(context).textTheme.displayLarge!;
  static TextStyle displayMedium(BuildContext context) => Theme.of(context).textTheme.displayMedium!;
  static TextStyle displaySmall(BuildContext context) => Theme.of(context).textTheme.displaySmall!;
  
  static TextStyle headlineLarge(BuildContext context) => Theme.of(context).textTheme.headlineLarge!;
  static TextStyle headlineMedium(BuildContext context) => Theme.of(context).textTheme.headlineMedium!;
  static TextStyle headlineSmall(BuildContext context) => Theme.of(context).textTheme.headlineSmall!;
  
  static TextStyle titleLarge(BuildContext context) => Theme.of(context).textTheme.titleLarge!;
  static TextStyle titleMedium(BuildContext context) => Theme.of(context).textTheme.titleMedium!;
  static TextStyle titleSmall(BuildContext context) => Theme.of(context).textTheme.titleSmall!;
  
  static TextStyle bodyLarge(BuildContext context) => Theme.of(context).textTheme.bodyLarge!;
  static TextStyle bodyMedium(BuildContext context) => Theme.of(context).textTheme.bodyMedium!;
  static TextStyle bodySmall(BuildContext context) => Theme.of(context).textTheme.bodySmall!;
  
  static TextStyle labelLarge(BuildContext context) => Theme.of(context).textTheme.labelLarge!;
  static TextStyle labelMedium(BuildContext context) => Theme.of(context).textTheme.labelMedium!;
  static TextStyle labelSmall(BuildContext context) => Theme.of(context).textTheme.labelSmall!;
}

class AppTransitions {
  static Route<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }
}
