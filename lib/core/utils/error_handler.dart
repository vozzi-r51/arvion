import 'package:flutter/material.dart';

class ErrorHandler {
  ErrorHandler._();

  static void showError(BuildContext context, dynamic error, {String? title}) {
    final message = error.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
    
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(title != null ? '$title: $message' : message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Runs an async task and automatically shows error SnackBar on failure.
  static Future<T?> run<T>(
    BuildContext context,
    Future<T> Function() task, {
    String? errorTitle,
    VoidCallback? onFinish,
  }) async {
    try {
      return await task();
    } catch (e) {
      if (context.mounted) {
        showError(context, e, title: errorTitle);
      }
      return null;
    } finally {
      onFinish?.call();
    }
  }
}
