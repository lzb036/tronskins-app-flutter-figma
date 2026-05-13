import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:tronskins_app/api/model/wallet/wallet_models.dart';
import 'package:tronskins_app/api/wallet.dart';
import 'package:tronskins_app/common/http/model/base_response.dart';
import 'package:tronskins_app/controllers/wallet/wallet_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory storageDirectory;

  setUpAll(() async {
    Get.testMode = true;
    storageDirectory = Directory.systemTemp.createTempSync(
      'tronskins_wallet_controller_test_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return switch (call.method) {
            'getApplicationDocumentsDirectory' => storageDirectory.path,
            'getApplicationSupportDirectory' => storageDirectory.path,
            'getTemporaryDirectory' => storageDirectory.path,
            'getApplicationCacheDirectory' => storageDirectory.path,
            _ => null,
          };
        });
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
  });

  tearDown(() async {
    Get.reset();
    await GetStorage().erase();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (storageDirectory.existsSync()) {
      try {
        storageDirectory.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can keep GetStorage files open briefly after the test.
      }
    }
  });

  group('WalletController fund flow date filter', () {
    test(
      'applyFundFlowDateRange sends day bounds and keeps them on paging',
      () async {
        final api = _FakeWalletApi()
          ..pages = [
            [_fakeFundFlow('flow-1')],
            [_fakeFundFlow('flow-2')],
          ];
        final controller = WalletController(api: api);

        await controller.applyFundFlowDateRange(
          startDate: DateTime(2026, 5, 1, 14, 30),
          endDate: DateTime(2026, 5, 3, 8),
        );
        await controller.loadFundFlows();

        final expectedStart =
            DateTime(2026, 5, 1).millisecondsSinceEpoch ~/ 1000;
        final expectedEnd =
            DateTime(2026, 5, 3, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;

        expect(api.calls, hasLength(2));
        expect(api.calls[0].page, 1);
        expect(api.calls[1].page, 2);
        expect(
          api.calls.every((call) => call.startTime == expectedStart),
          true,
        );
        expect(api.calls.every((call) => call.endTime == expectedEnd), true);
        expect(controller.fundFlows, hasLength(2));
      },
    );

    test(
      'clearFundFlowDateRange reloads first page without date params',
      () async {
        final api = _FakeWalletApi()
          ..pages = [
            [_fakeFundFlow('filtered')],
          ];
        final controller = WalletController(api: api);

        await controller.applyFundFlowDateRange(
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 2),
        );
        api
          ..calls.clear()
          ..pages = [
            [_fakeFundFlow('cleared')],
          ];

        await controller.clearFundFlowDateRange();

        expect(api.calls, hasLength(1));
        expect(api.calls.single.page, 1);
        expect(api.calls.single.startTime, isNull);
        expect(api.calls.single.endTime, isNull);
        expect(controller.fundFlowStartDate.value, isNull);
        expect(controller.fundFlowEndDate.value, isNull);
        expect(controller.fundFlows.single.id, 'cleared');
      },
    );
  });

  group('WalletController withdraw address selection', () {
    test('keeps selected withdraw address when wallet list reloads', () async {
      final addressA = _fakeWithdrawAddress('address-a');
      final addressB = _fakeWithdrawAddress('address-b');
      final api = _FakeWalletApi()..withdrawAddresses = [addressA, addressB];
      final controller = WalletController(api: api);

      await controller.loadWithdrawAddresses();
      expect(controller.selectedWithdrawAddress.value?.id, 'address-a');

      controller.selectWithdrawAddress(addressB);
      await controller.loadWithdrawAddresses();

      expect(controller.selectedWithdrawAddress.value?.id, 'address-b');
    });

    test('restores remembered withdraw address in a new controller', () async {
      final addressA = _fakeWithdrawAddress('address-a');
      final addressB = _fakeWithdrawAddress('address-b');
      final firstController = WalletController(
        api: _FakeWalletApi()..withdrawAddresses = [addressA, addressB],
      );

      await firstController.loadWithdrawAddresses();
      firstController.selectWithdrawAddress(addressB);

      final secondController = WalletController(
        api: _FakeWalletApi()..withdrawAddresses = [addressA, addressB],
      );
      await secondController.loadWithdrawAddresses();

      expect(secondController.selectedWithdrawAddress.value?.id, 'address-b');
    });
  });
}

WalletFundFlowItem _fakeFundFlow(String id) {
  return WalletFundFlowItem(
    id: id,
    serialNumber: id,
    type: 1,
    typeName: '充值',
    amount: 1,
    beforeBalance: 10,
    createTime: 1778457600,
  );
}

WalletWithdrawAddress _fakeWithdrawAddress(String id) {
  return WalletWithdrawAddress(
    id: id,
    name: 'Wallet $id',
    account: 'account-$id',
  );
}

class _FakeWalletApi extends ApiWalletServer {
  List<List<WalletFundFlowItem>> pages = const [];
  List<WalletWithdrawAddress> withdrawAddresses = const [];
  final List<_FundFlowCall> calls = [];

  @override
  Future<BaseHttpResponse<WalletListResponse<WalletFundFlowItem>>>
  fundChangesList({
    int page = 1,
    int pageSize = 20,
    int? startTime,
    int? endTime,
  }) async {
    calls.add(
      _FundFlowCall(
        page: page,
        pageSize: pageSize,
        startTime: startTime,
        endTime: endTime,
      ),
    );
    final list = page <= pages.length
        ? pages[page - 1]
        : const <WalletFundFlowItem>[];
    final total = pages.fold<int>(0, (sum, items) => sum + items.length);
    return BaseHttpResponse<WalletListResponse<WalletFundFlowItem>>(
      code: 200,
      message: '',
      datas: WalletListResponse<WalletFundFlowItem>(
        list: list,
        pager: WalletPager(
          page: page,
          pageSize: pageSize,
          total: total,
          pages: pages.length,
        ),
      ),
    );
  }

  @override
  Future<BaseHttpResponse<List<WalletWithdrawAddress>>>
  withdrawWalletList() async {
    return BaseHttpResponse<List<WalletWithdrawAddress>>(
      code: 0,
      message: '',
      datas: withdrawAddresses,
    );
  }
}

class _FundFlowCall {
  const _FundFlowCall({
    required this.page,
    required this.pageSize,
    required this.startTime,
    required this.endTime,
  });

  final int page;
  final int pageSize;
  final int? startTime;
  final int? endTime;
}
