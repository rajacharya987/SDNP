import 'package:flutter_test/flutter_test.dart';

import 'package:scamlink/main.dart';
import 'package:scamlink/theme/app_icons.dart';

void main() {
  testWidgets('Splash then home dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ScamLinkApp());

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.text('Device Protected'), findsOneWidget);
    expect(find.text('Scan Link'), findsOneWidget);
    expect(find.byIcon(AppIcons.homeFilled), findsOneWidget);
    expect(find.byIcon(AppIcons.history), findsWidgets);
  });
}
