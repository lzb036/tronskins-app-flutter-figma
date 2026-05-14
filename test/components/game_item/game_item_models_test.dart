import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/components/game_item/game_item_models.dart';

void main() {
  test('parseGemList keeps Dota gem display fields', () {
    final gems = parseGemList([
      {
        'imageUrl':
            'https://cdn.steamstatic.com/apps/570/icons/econ/sockets/gem.png',
        'borderColor': 'rgb(255, 255, 255)',
        'gemType': 'Inscribed Gem',
        'statInfo': 'Kills: 2385',
        'market_price': 1.23,
      },
    ]);

    expect(gems, hasLength(1));
    expect(gems.single.imageUrl, contains('/gem.png'));
    expect(gems.single.borderColor, const Color(0xFFFFFFFF));
    expect(gems.single.name, 'Inscribed Gem');
    expect(gems.single.statInfo, 'Kills: 2385');
    expect(gems.single.price, 1.23);
  });
}
