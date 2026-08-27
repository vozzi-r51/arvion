import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanedge/core/widgets/arvion_logo.dart';
import 'package:dukanedge/core/widgets/motion_widgets.dart';

void main() {
  testWidgets('ArvionLogo renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArvionLogo(size: 40),
        ),
      ),
    );

    expect(find.byType(ArvionLogo), findsOneWidget);
  });

  testWidgets('AnimatedCountText animates numerical text smoothly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedCountText(
            value: 1500.0,
            prefix: 'Rs. ',
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedCountText), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Rs. 1500'), findsOneWidget);
  });

  testWidgets('PulsingBadge renders child widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulsingBadge(
            child: Text('Warning Badge'),
          ),
        ),
      ),
    );

    expect(find.text('Warning Badge'), findsOneWidget);
  });
}
