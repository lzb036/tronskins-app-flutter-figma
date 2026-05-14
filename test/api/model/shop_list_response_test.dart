import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/api/model/shop/shop_models.dart';

void main() {
  test('ShopListResponse exposes schema aliases by id and name', () {
    final response = ShopListResponse<ShopOrderItem>.fromJson(
      {
        'schemas': {
          'AK-47 | Inheritance (Field-Tested)': {
            'id': '41355',
            'market_hash_name': 'AK-47 | Inheritance (Field-Tested)',
            'market_name': 'AK-47 | Inheritance (Field-Tested)',
            'image_url': 'weapon.png',
          },
        },
        'sends': [
          {
            'id': '1',
            'details': [
              {'schema_id': '41355', 'price': 1},
            ],
          },
        ],
      },
      ShopOrderItem.fromJson,
      listKey: 'sends',
    );

    expect(response.schemas['41355']?.imageUrl, 'weapon.png');
    expect(
      response.schemas['AK-47 | Inheritance (Field-Tested)']?.imageUrl,
      'weapon.png',
    );
  });

  test('ShopListResponse exposes sticker and keychain metadata as schemas', () {
    final response = ShopListResponse<ShopOrderItem>.fromJson(
      {
        'stickers': {
          '36551': {
            'id': '36551',
            'baseId': '1000000-4713',
            'market_hash_name': 'Sticker | Astralis | 2020 RMR',
            'market_name': 'Sticker | Astralis | 2020 RMR',
            'image_url': 'sticker.png',
          },
        },
        'keychains': {
          '42915': {
            'id': '42915',
            'baseId': '3000000-6',
            'market_hash_name': "Charm | Lil' Crass",
            'market_name': "Charm | Lil' Crass",
            'image_url': 'charm.png',
          },
        },
        'sends': [
          {
            'id': '1',
            'details': [
              {'schema_id': '36551', 'price': 1},
            ],
          },
        ],
      },
      ShopOrderItem.fromJson,
      listKey: 'sends',
    );

    expect(response.stickers['36551']['image_url'], 'sticker.png');
    expect(
      response.schemas['36551']?.marketName,
      'Sticker | Astralis | 2020 RMR',
    );
    expect(response.schemas['1000000-4713']?.imageUrl, 'sticker.png');
    expect(response.schemas['42915']?.marketName, "Charm | Lil' Crass");
    expect(response.schemas['3000000-6']?.imageUrl, 'charm.png');
  });
}
