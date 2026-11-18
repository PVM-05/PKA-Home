import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/adaptive_master_detail_layout.dart';
import 'golden_test_helper.dart';

void main() {
  setUpAll(() {
    setupGoldenTests();
  });

  group('AdaptiveMasterDetailLayout Golden Tests', () {
    testWidgets('Desktop split layout renders master and detail columns', (tester) async {
      await pumpGoldenWidget(
        tester,
        SizedBox(
          height: 500,
          child: AdaptiveMasterDetailLayout<String>(
            masterBuilder: (context, isMasterPaneOnly) {
              return ListView(
                children: const [
                  ListTile(title: Text('Mục 1 (Được chọn)'), selected: true),
                  ListTile(title: Text('Mục 2')),
                  ListTile(title: Text('Mục 3')),
                ],
              );
            },
            selectedItem: 'Mục 1',
            detailBuilder: (context, item) {
              return Center(
                child: Text('Chi tiết cho: $item'),
              );
            },
          ),
        ),
        surfaceSize: const Size(1024, 600),
        isDark: false,
      );

      await expectLater(
        find.byType(AdaptiveMasterDetailLayout<String>),
        matchesGoldenFile('goldens/master_detail_desktop_selected.png'),
      );
    });

    testWidgets('Desktop split layout renders empty placeholder when no selection', (tester) async {
      await pumpGoldenWidget(
        tester,
        SizedBox(
          height: 500,
          child: AdaptiveMasterDetailLayout<String>(
            masterBuilder: (context, isMasterPaneOnly) {
              return ListView(
                children: const [
                  ListTile(title: Text('Mục 1')),
                  ListTile(title: Text('Mục 2')),
                ],
              );
            },
            selectedItem: null,
            detailBuilder: (context, item) => const SizedBox.shrink(),
          ),
        ),
        surfaceSize: const Size(1024, 600),
        isDark: false,
      );

      await expectLater(
        find.byType(AdaptiveMasterDetailLayout<String>),
        matchesGoldenFile('goldens/master_detail_desktop_empty.png'),
      );
    });
  });
}
