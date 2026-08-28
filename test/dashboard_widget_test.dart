import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bizmanager/core/widgets/bizmanager_logo.dart';
import 'package:bizmanager/core/widgets/motion_widgets.dart';

void main() {
  testWidgets('BizManagerLogo renders without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BizManagerLogo(size: 40),
        ),
      ),
    );

    expect(find.byType(BizManagerLogo), findsOneWidget);
  });

  testWidgets('AnimatedCountText animates numerical text smoothly',
      (WidgetTester tester) async {
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
