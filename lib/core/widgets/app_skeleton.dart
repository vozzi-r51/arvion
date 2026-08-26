import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/design_tokens.dart';

class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double? borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.s),
        ),
      ),
    );
  }

  static Widget listTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s, horizontal: AppSpacing.l),
      child: Row(
        children: [
          const AppSkeleton(width: 48, height: 48, borderRadius: 24),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(width: double.infinity, height: 16),
                const SizedBox(height: AppSpacing.xs),
                AppSkeleton(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget card({double height = 100}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: AppSkeleton(
        width: double.infinity,
        height: height,
        borderRadius: AppRadius.m,
      ),
    );
  }
}
