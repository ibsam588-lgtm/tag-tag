import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tag_tag_playground_blitz/main.dart';

void main() {
  testWidgets('opens home then starts playable HUD', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TagTagApp());
    await tester.pump();

    expect(find.text('TAG TAG'), findsOneWidget);
    expect(find.text('STORE'), findsOneWidget);
    expect(find.text('SETUP'), findsOneWidget);

    await tester.ensureVisible(find.text('PLAY'));
    await tester.pump();
    await tester.tap(find.text('PLAY'));
    await tester.pump();

    expect(find.text('Stamina Chase'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('DASH'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });
}
