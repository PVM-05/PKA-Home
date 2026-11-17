import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/models/building_rule_model.dart';
import 'package:vivona/data/models/emergency_contact_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/handbook_provider.dart';
import 'package:vivona/data/repositories/auth_repository.dart';
import 'package:vivona/data/repositories/handbook_repository.dart';
import 'package:vivona/features/management/screens/handbook_management_screen.dart';
import 'package:vivona/features/resident/screens/resident_handbook_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockHandbookRepository implements HandbookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthRepository implements AuthRepository {
  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier(UserModel user) : super(_MockAuthRepository()) {
    state = AsyncValue.data(user);
  }
}

void main() {
  final now = DateTime.now();

  final mockContacts = <EmergencyContactModel>[
    EmergencyContactModel(
      id: 'contact-01',
      name: 'Hotline Bảo Vệ & An Ninh Tòa Nhà',
      phone: '0901234567',
      contactType: 'security',
      displayOrder: 1,
      createdAt: now,
    ),
    EmergencyContactModel(
      id: 'contact-02',
      name: 'Đội Kỹ Thuật Điện Nước Trực Ca 24/7',
      phone: '0909876543',
      contactType: 'technical',
      displayOrder: 2,
      createdAt: now,
    ),
  ];

  final mockRules = <BuildingRuleModel>[
    BuildingRuleModel(
      id: 'rule-01',
      title: 'Giữ gìn an ninh trật tự và quy định khung giờ yên tĩnh',
      content:
          'Sau 22h00 đêm, cư dân vui lòng không gây tiếng ồn lớn, hát karaoke hoặc tụ tập đông người làm ảnh hưởng các căn lân cận.',
      displayOrder: 1,
      createdAt: now,
    ),
  ];

  final mockAmenities = <BuildingAmenityModel>[
    BuildingAmenityModel(
      id: 'amenity-01',
      name: 'Hồ Bơi Vô Cực Trên Tầng Thượng Tháp A',
      description: 'Phục vụ cư dân miễn phí, yêu cầu mặc trang phục bơi tiêu chuẩn.',
      openHours: '06:00 - 21:00',
      bookingType: 'shared',
      maxCapacity: 30,
      feeAmount: 0,
      displayOrder: 1,
      createdAt: now,
    ),
  ];

  Widget createManagementWidget() {
    final mockManager = UserModel(
      id: 'mgr-01',
      fullName: 'Quản lý Nguyễn Văn B',
      role: 'management',
    );

    return ProviderScope(
      overrides: [
        handbookRepositoryProvider.overrideWithValue(_MockHandbookRepository()),
        authProvider.overrideWith((ref) => _MockAuthNotifier(mockManager)),
        emergencyContactsProvider.overrideWith((ref) => Future.value(mockContacts)),
        buildingRulesProvider.overrideWith((ref) => Future.value(mockRules)),
        buildingAmenitiesProvider.overrideWith((ref) => Future.value(mockAmenities)),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HandbookManagementScreen(),
      ),
    );
  }

  Widget createResidentWidget() {
    final mockResident = UserModel(
      id: 'res-01',
      fullName: 'Cư dân Lê Thị C',
      role: 'resident',
    );

    return ProviderScope(
      overrides: [
        handbookRepositoryProvider.overrideWithValue(_MockHandbookRepository()),
        authProvider.overrideWith((ref) => _MockAuthNotifier(mockResident)),
        emergencyContactsProvider.overrideWith((ref) => Future.value(mockContacts)),
        buildingRulesProvider.overrideWith((ref) => Future.value(mockRules)),
        buildingAmenitiesProvider.overrideWith((ref) => Future.value(mockAmenities)),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ResidentHandbookScreen(),
      ),
    );
  }

  group('HandbookManagementScreen Responsive Tests', () {
    testWidgets('renders desktop workstation cleanly at 1200dp width', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createManagementWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quản Lý Cẩm Nang Tòa Nhà'), findsOneWidget);
      expect(find.text('Hotline Bảo Vệ & An Ninh Tòa Nhà'), findsOneWidget);
    });

    testWidgets('renders mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(createManagementWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quản Lý Cẩm Nang Tòa Nhà'), findsOneWidget);
      expect(find.textContaining('Hotline Bảo Vệ'), findsOneWidget);
    });
  });

  group('ResidentHandbookScreen Responsive Tests', () {
    testWidgets('renders desktop workstation cleanly at 1200dp width', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createResidentWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cẩm Nang Cư Dân'), findsOneWidget);
      expect(find.text('Hotline Bảo Vệ & An Ninh Tòa Nhà'), findsOneWidget);
      expect(find.text('Gọi ngay'), findsNWidgets(2));
    });

    testWidgets('renders mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(createResidentWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cẩm Nang Cư Dân'), findsOneWidget);
      expect(find.textContaining('Hotline Bảo Vệ'), findsOneWidget);
      expect(find.text('Gọi ngay'), findsWidgets);
    });
  });
}
