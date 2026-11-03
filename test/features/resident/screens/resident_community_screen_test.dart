import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/poll_model.dart';
import 'package:pka_home/data/models/petition_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/community_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
import 'package:pka_home/features/resident/screens/resident_community_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ResidentCommunityScreen hien thi day du 2 tabs va nut tuong tac', (tester) async {
    const testAptId = 'apt-01';

    final mockPolls = [
      PollModel(
        id: 'poll-01',
        pollCode: 'POLL-202611-00001',
        title: 'Biểu quyết sửa đổi quy chế tòa nhà năm 2027',
        description: 'Bổ sung quy định tiếng ồn sau 22h00',
        category: 'rule',
        voteWeightType: 'by_area',
        choiceType: 'single_choice',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 3)),
        status: 'active',
        createdAt: DateTime.now(),
        options: const [
          PollOptionModel(id: 'opt-01', pollId: 'poll-01', optionText: 'Đồng ý sửa đổi', optionOrder: 1),
        ],
        hasVoted: false,
      ),
    ];

    final mockPetitions = [
      PetitionModel(
        id: 'pet-01',
        petitionCode: 'PET-202611-00001',
        apartmentId: testAptId,
        authorUserId: 'usr-01',
        title: 'Đề xuất mở phòng Gym lúc 5h30 sáng',
        content: 'Tạo điều kiện cho cư dân tập trước giờ đi làm',
        endorsementCount: 25,
        status: 'pending',
        createdAt: DateTime.now(),
        isEndorsedByMe: false,
      ),
    ];

    final testUser = UserModel(
      id: 'usr-01',
      fullName: 'Cư Dân Test',
      role: 'resident',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          selectedApartmentIdProvider.overrideWith((ref) => SelectedApartmentNotifier()..selectApartment(testAptId)),
          pollsProvider((status: null, apartmentId: testAptId)).overrideWith((ref) => Future.value(mockPolls)),
          petitionsProvider((status: null, category: null, apartmentId: testAptId)).overrideWith((ref) => Future.value(mockPetitions)),
        ],
        child: const MaterialApp(
          home: ResidentCommunityScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và tabs
    expect(find.text('Biểu Quyết & Cộng Đồng'), findsOneWidget);
    expect(find.text('Biểu Quyết & Khảo Sát'), findsOneWidget);
    expect(find.text('Ý Kiến & Kiến Nghị'), findsOneWidget);

    // 2. Tab 1: Biểu quyết
    expect(find.text('Biểu quyết sửa đổi quy chế tòa nhà năm 2027'), findsOneWidget);
    expect(find.text('POLL-202611-00001'), findsOneWidget);
    expect(find.text('Tham Gia Biểu Quyết'), findsOneWidget);

    // 3. Chuyển sang Tab 2: Ý kiến & Kiến nghị
    await tester.tap(find.text('Ý Kiến & Kiến Nghị'));
    await tester.pumpAndSettle();

    expect(find.text('Đề xuất mở phòng Gym lúc 5h30 sáng'), findsOneWidget);
    expect(find.textContaining('Đồng thuận (25)'), findsOneWidget);
  });
}

