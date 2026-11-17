import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/link_request_management_provider.dart';
import 'package:vivona/data/providers/link_request_provider.dart';
import 'package:vivona/features/management/screens/link_request_management_screen.dart';
import 'package:vivona/features/resident/screens/link_request_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResidentLinkNotifier extends StateNotifier<ResidentLinkStatus>
    implements ResidentLinkNotifier {
  FakeResidentLinkNotifier() : super(ResidentLinkStatus(status: LinkStatus.none));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLinkRequestManagementNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements LinkRequestManagementNotifier {
  FakeLinkRequestManagementNotifier(List<Map<String, dynamic>> data)
      : super(AsyncValue.data(data));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Ban Quản Lý Tòa Nhà',
    role: 'admin',
  );

  final mockRequests = [
    {
      'id': 'req-1',
      'user_id': 'user-1',
      'apartment_id': 'apt-1',
      'requested_relation_role': 'owner',
      'created_at': DateTime.now().toIso8601String(),
      'users': {
        'id': 'user-1',
        'full_name': 'Nguyễn Văn Cư Dân',
      },
      'apartments': {
        'id': 'apt-1',
        'code': 'A0110',
      },
    },
    {
      'id': 'req-2',
      'user_id': 'user-2',
      'apartment_id': 'apt-2',
      'requested_relation_role': 'tenant',
      'created_at': DateTime.now().toIso8601String(),
      'users': {
        'id': 'user-2',
        'full_name': 'Lê Thị Khách Thuê Dài Hạn',
      },
      'apartments': {
        'id': 'apt-2',
        'code': 'B0205',
      },
    },
  ];

  Widget buildManagementTestWidget({required Size screenSize, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        linkRequestManagementProvider.overrideWith((ref) => FakeLinkRequestManagementNotifier(mockRequests)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const LinkRequestManagementScreen(),
        ),
      ),
    );
  }

  Widget buildResidentTestWidget({required Size screenSize, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
        availableApartmentsProvider.overrideWith((ref) => Future.value([])),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const LinkRequestScreen(),
        ),
      ),
    );
  }

  group('LinkRequest Responsive & Anti-RenderFlex Tests', () {
    testWidgets('LinkRequestManagementScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildManagementTestWidget(screenSize: const Size(320, 600), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Duyệt yêu cầu liên kết'), findsOneWidget);
      expect(find.text('Nguyễn Văn Cư Dân'), findsOneWidget);
      expect(find.text('Căn hộ: A0110'), findsOneWidget);
    });

    testWidgets('LinkRequestManagementScreen renders centered on 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildManagementTestWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Duyệt yêu cầu liên kết'), findsOneWidget);
      expect(find.text('Phê duyệt'), findsWidgets);
    });

    testWidgets('LinkRequestScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildResidentTestWidget(screenSize: const Size(320, 600), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Liên kết căn hộ của bạn'), findsOneWidget);
    });
  });
}
