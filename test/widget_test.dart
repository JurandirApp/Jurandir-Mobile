import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jurandir/app.dart';

void main() {
  testWidgets('app inicia no Splash e avança', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JurandirApp()));
    await tester.pump();

    expect(find.text('SEU GARÇOM DIGITAL'), findsOneWidget);

    // Deixa o timer de 2s disparar e navegar pro onboarding.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
