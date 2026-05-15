double? marketListingDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(
    text.replaceAll(r'$', '').replaceAll(',', '').replaceAll('%', ''),
  );
}

int? marketListingInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString().trim());
}

int? marketListingSellCount(Map<String, dynamic> raw) {
  const keys = [
    'sell_num',
    'sellNum',
    'selling_num',
    'sellingNum',
    'sell_count',
    'sellCount',
    'sale_count',
    'saleCount',
    'on_sale_num',
    'onSaleNum',
    'on_sale_count',
    'onSaleCount',
  ];
  for (final key in keys) {
    final count = marketListingInt(raw[key]);
    if (count != null) {
      return count;
    }
  }
  return null;
}

double activeLowestListingPrice(
  Map<String, dynamic> raw, {
  double minimumPrice = 0,
  Iterable<String> priceKeys = const [
    'sell_min',
    'sellMin',
    'lowest_sell_price',
    'lowestSellPrice',
    'market_price',
    'marketPrice',
    'price',
  ],
}) {
  final sellCount = marketListingSellCount(raw);
  if (sellCount != null && sellCount <= 0) {
    return 0;
  }

  final prices = <double>[];
  for (final key in priceKeys) {
    final price = marketListingDouble(raw[key]);
    if (price != null && price > 0) {
      prices.add(price);
    }
  }
  if (prices.isEmpty) {
    return 0;
  }
  final lowest = prices.reduce((a, b) => a < b ? a : b);
  if (minimumPrice > 0 && lowest < minimumPrice) {
    return minimumPrice;
  }
  return lowest;
}
