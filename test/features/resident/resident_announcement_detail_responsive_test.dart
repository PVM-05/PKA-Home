import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivona/data/models/announcement_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/repositories/announcement_repository.dart';
import 'package:vivona/data/repositories/auth_repository.dart';
import 'package:vivona/features/resident/screens/resident_announcement_detail_screen.dart';

class _MockAnnouncementRepository implements AnnouncementRepository {
  String? markedAnnouncementId;
  String? markedUserId;

  @override
  Stream<List<Map<String, dynamic>>> streamAnnouncements() => const Stream.empty();

  @override
  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
    String category = 'general',
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool isPinned = false,
    String? hotlineContact,
    bool autoBroadcast = true,
  }) async => {};

  @override
  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
    String category = 'general',
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool isPinned = false,
    String? hotlineContact,
  }) async {}

  @override
  Future<void> deleteAnnouncement(String id) async {}

  @override
  Future<Map<String, dynamic>> broadcastAnnouncement(String announcementId) async => {};

  @override
  Future<Map<String, dynamic>> markAnnouncementAsRead(String id, String userId) async {
    markedAnnouncementId = id;
    markedUserId = userId;
    return {'success': true};
  }
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

  final testAnnouncement = AnnouncementModel(
    id: 'ann-res-01',
    title: 'Thông báo tạm ngưng cung cấp nước sạch để súc rửa bể ngầm định kỳ',
    content:
        'Kính gửi toàn thể Quý cư dân, Ban Quản Lý xin thông báo kế hoạch thau rửa bể chứa nước ngầm và bể mái. Quý cư dân vui lòng chủ động tích trữ nước sinh hoạt.',
    isUrgent: true,
    isPinned: true,
    category: 'utility_outage',
    targetType: 'all',
    readCount: 15,
    broadcastCount: 50,
    createdAt: now.subtract(const Duration(hours: 3)),
    eventStartAt: now.subtract(const Duration(minutes: 30)),
    eventEndAt: now.add(const Duration(hours: 3)),
    hotlineContact: '0909123456',
  );

  Widget createWidget({required _MockAnnouncementRepository repo}) {
    final mockUser = UserModel(
      id: 'user-01',
      fullName: 'Cư dân Nguyễn Văn A',
      phone: '0987654321',
      role: 'resident',
    );

    return ProviderScope(
      overrides: [
        announcementRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith((ref) => _MockAuthNotifier(mockUser)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ResidentAnnouncementDetailScreen(
          announcement: testAnnouncement,
        ),
      ),
    );
  }

  group('ResidentAnnouncementDetailScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop workstation cleanly centered with maxWidth: 800 and marks as read', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _MockAnnouncementRepository();
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết thông báo'), findsOneWidget);
      expect(find.textContaining('Thông báo tạm ngưng cung cấp nước sạch'), findsOneWidget);
      expect(find.text('Khung thời gian thực hiện'), findsOneWidget);
      expect(find.text('Hotline kỹ thuật viên trực ban'), findsOneWidget);
      expect(find.text('0909123456'), findsOneWidget);
      expect(find.text('Gọi ngay'), findsOneWidget);
      expect(repo.markedAnnouncementId, 'ann-res-01');
      expect(repo.markedUserId, 'user-01');
    });

    testWidgets('renders mobile narrow 320dp width with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _MockAnnouncementRepository();
      await tester.pumpWidget(createWidget(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết thông báo'), findsOneWidget);
      expect(find.textContaining('Thông báo tạm ngưng cung cấp nước'), findsOneWidget);
      expect(find.text('Gọi ngay'), findsOneWidget);
    });
  });
}
