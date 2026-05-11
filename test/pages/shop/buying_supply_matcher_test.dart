import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';
import 'package:tronskins_app/pages/shop/buying_supply_matcher.dart';

void main() {
  group('matchesBuyRequestSupplyConstraints', () {
    test('rejects inventory outside requested wear range', () {
      final request = BuyRequestItem(
        raw: const {
          'appId': 730,
          'schemaId': 41355,
          'paintWearMin': 0.18,
          'paintWearMax': 0.21,
        },
        appId: 730,
        schemaId: 41355,
        paintWearMin: 0.18,
        paintWearMax: 0.21,
      );

      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(schemaId: 41355, paintWear: 0.1975),
        ),
        isTrue,
      );
      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(schemaId: 41355, paintWear: 0.2222),
        ),
        isFalse,
      );
    });

    test('rejects wrong schema even when the name looks similar', () {
      final request = BuyRequestItem(
        raw: const {'appId': 730, 'schemaId': 41355},
        appId: 730,
        schemaId: 41355,
      );

      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(schemaId: 41356, paintWear: 0.19),
        ),
        isFalse,
      );
    });

    test('checks paint index and fade percentage requirements', () {
      final request = BuyRequestItem(
        raw: const {
          'appId': 730,
          'schemaId': 41249,
          'paintIndex': '38',
          'paintGradientMin': 95,
          'paintGradientMax': 100,
        },
        appId: 730,
        schemaId: 41249,
        percentageMin: 95,
        percentageMax: 100,
      );

      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(
            schemaId: 41249,
            paintIndex: '38',
            percentage: '98.5%',
          ),
        ),
        isTrue,
      );
      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(
            schemaId: 41249,
            paintIndex: '39',
            percentage: '98.5%',
          ),
        ),
        isFalse,
      );
      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(
            schemaId: 41249,
            paintIndex: '38',
            percentage: '94.9%',
          ),
        ),
        isFalse,
      );
    });

    test('matches accepted pattern or phase requirements', () {
      final request = BuyRequestItem(
        raw: const {
          'appId': 730,
          'schemaId': 39290,
          'accepted_patterns': ['Phase 2'],
        },
        appId: 730,
        schemaId: 39290,
      );

      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(schemaId: 39290, phase: 'Phase 2'),
        ),
        isTrue,
      );
      expect(
        matchesBuyRequestSupplyConstraints(
          request,
          _csgoInventoryItem(schemaId: 39290, phase: 'Phase 3'),
        ),
        isFalse,
      );
    });
  });
}

InventoryItem _csgoInventoryItem({
  required int schemaId,
  double? paintWear,
  String? paintIndex,
  String? phase,
  dynamic percentage,
}) {
  return InventoryItem(
    raw: {
      'app_id': 730,
      'schema_id': schemaId,
      'csgoAsset': {
        'app_id': 730,
        'schema_id': schemaId.toString(),
        if (paintWear != null) 'paint_wear': paintWear,
        if (paintIndex != null) 'paint_index': paintIndex,
        if (phase != null) 'phase': phase,
        if (percentage != null) 'percentage': percentage,
      },
    },
    appId: 730,
    schemaId: schemaId,
    paintWear: paintWear,
    phase: phase,
  );
}
