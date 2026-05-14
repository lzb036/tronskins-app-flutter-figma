import 'package:flutter_test/flutter_test.dart';
import 'package:tronskins_app/common/utils/shop_online_status.dart';

void main() {
  test('prefers explicit shop status over generic online flag', () {
    expect(
      extractShopOnlineStatus({
        'online': false,
        'shop': {'isOnline': true},
      }),
      isTrue,
    );
  });

  test('returns null when no shop online status is exposed', () {
    expect(extractShopOnlineStatus({'uuid': 'seller-1'}), isNull);
  });

  test('parses numeric and string shop online values', () {
    expect(extractShopOnlineStatus({'is_online': 1}), isTrue);
    expect(extractShopOnlineStatus({'shop_online': 'off'}), isFalse);
  });
}
