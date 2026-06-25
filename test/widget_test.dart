import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag_tag_playground_blitz/main.dart';

void main() {
  testWidgets('opens directly to playable HUD', (tester) async {
    await tester.pumpWidget(const TagTagApp());
    await tester.pump();

    expect(find.text('Stamina Chase'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('DASH'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });
}
