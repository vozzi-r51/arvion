import 'package:flutter/material.dart';
import 'app_empty_state.dart';
import 'app_skeleton.dart';

/// Unified 3-State Trilogy Widget (Loading, Error/Empty, Content).
/// Enforces consistent UI across all screens in ARVION.
class AppTriStateBuilder<T> extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<T>? items;
  final Widget Function() contentBuilder;
  final Widget Function()? loadingBuilder;
  final Widget Function()? emptyBuilder;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  const AppTriStateBuilder({
    super.key,
    required this.isLoading,
    this.errorMessage,
    this.items,
    required this.contentBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.onRetry,
    this.emptyTitle = 'Koi Record Nahi Mila',
    this.emptyMessage = 'Abhi tak is module mein koi data add nahi hua.',
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      if (loadingBuilder != null) return loadingBuilder!();
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => AppSkeleton.listTile(),
      );
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              if (onRetry != null)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Dobara Koshish Karein'),
                ),
            ],
          ),
        ),
      );
    }

    if (items != null && items!.isEmpty) {
      if (emptyBuilder != null) return emptyBuilder!();
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return contentBuilder();
  }
}
