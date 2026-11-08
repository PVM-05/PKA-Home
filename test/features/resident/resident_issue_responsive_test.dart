import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
import 'package:pka_home/data/providers/resident_issue_provider.dart';
import 'package:pka_home/features/resident/screens/create_issue_screen.dart';
import 'package:pka_home/features/resident/screens/resident_issue_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testUser = UserModel(
    id: 'user-resident-1',
    fullName: 'Nguyễn Văn Cư Dân',
    phone: '0901234567',
    role: 'resident',
  );

  final mockIssues = [
    IssueModel(
      id: 'issue-1',
      apartmentId: 'apt-1',
      reporterId: 'user-resident-1',
      description: 'Đèn chiếu sáng khu vực ban công chập chờn liên tục, có tiếng nổ lách tách',
      priority: 'high',
      status: 'pending',
      category: 'electrical',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      imageUrls: ['https://example.com/img1.jpg'],
    ),
    IssueModel(
      id: 'issue-2',
      apartmentId: 'apt-1',
      reporterId: 'user-resident-1',
      description: 'Đường ống thoát nước sàn nhà tắm thoát chậm cần thông tắc',
      priority: 'medium',
      status: 'in_progress',
      category: 'plumbing',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Widget buildResidentIssueApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentIssueProvider.overrideWith((ref) async => mockIssues),
        currentSelectedApartmentProvider.overrideWith((ref) => {
          'apartment_id': 'apt-1',
          'code': 'A0110',
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const ResidentIssueScreen(),
        ),
      ),
    );
  }

  Widget buildCreateIssueApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        currentSelectedApartmentProvider.overrideWith((ref) => {
          'apartment_id': 'apt-1',
          'code': 'A0110',
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const CreateIssueScreen(),
        ),
      ),
    );
  }

  group('ResidentIssueScreen Responsive Tests', () {
    testWidgets('renders desktop layout at 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildResidentIssueApp(width: 1000, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Phản ánh sự cố'), findsOneWidget);
      expect(find.textContaining('Đèn chiếu sáng'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildResidentIssueApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Phản ánh sự cố'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildResidentIssueApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Phản ánh sự cố'), findsOneWidget);
    });
  });

  group('CreateIssueScreen Responsive Tests', () {
    testWidgets('renders desktop layout at 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateIssueApp(width: 1000, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Gửi Phản Ánh'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'GỬI YÊU CẦU'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateIssueApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Gửi Phản Ánh'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCreateIssueApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Gửi Phản Ánh'), findsOneWidget);
    });
  });
}
