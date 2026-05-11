import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/common/widgets/shrinking_price_text.dart';

void main() {
  testWidgets('ShrinkingPriceText uses scale down instead of ellipsis', (
    tester,
  ) async {
    const priceText = r'$ 26356000.00';

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 72,
            child: ShrinkingPriceText(
              text: priceText,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );

    expect(find.text(priceText), findsOneWidget);

    final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
    expect(fittedBox.fit, BoxFit.scaleDown);
  });
}
