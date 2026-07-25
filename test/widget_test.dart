import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:write4me/homepage.dart';

void main() {
  testWidgets('writing workspace renders its primary controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('Write4Me'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('What are we writing?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
