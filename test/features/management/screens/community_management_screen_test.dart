import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/poll_model.dart';
import 'package:pka_home/data/models/petition_model.dart';
import 'package:pka_home/data/providers/community_provider.dart';
import 'package:pka_home/features/management/screens/community_management_screen.dart';

void main() {
  testWidgets('CommunityManagementScreen hien thi day du 2 tabs va thong tin KPI', (tester) async {
    final mockPolls = [
      PollModel(
        id: 'poll-01',
        pollCode: 'POLL-202611-00001',
        title: 'Biểu quyết lựa chọn đơn vị vận hành năm 2027',
        description: 'Đánh giá hồ sơ thầu',
        category: 'agm',
        voteWeightType: 'by_area',
        choiceType: 'single_choice',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 2)),
        status: 'active',
        createdAt: DateTime.now(),
        options: const [
          PollOptionModel(id: 'opt-01', pollId: 'poll-01', optionText: 'Savills', optionOrder: 1),
        ],
      ),
    ];

    final mockPetitions = [
      PetitionModel(
        id: 'pet-01',
        petitionCode: 'PET-202611-00001',
        apartmentId: 'apt-01',
        apartmentCode: 'A0502',
        authorUserId: 'usr-01',
        authorName: 'Nguyễn Văn Nam',
        title: 'Đề xuất lắp thêm camera hành lang tầng 5',
        content: 'Khu vực hành lang chưa có camera',
        endorsementCount: 12,
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pollsProvider((status: null, apartmentId: null)).overrideWith((ref) => Future.value(mockPolls)),
          petitionsProvider((status: null, category: null, apartmentId: null)).overrideWith((ref) => Future.value(mockPetitions)),
          communityStatsProvider.overrideWith((ref) => Future.value({
            'activePolls': 1,
            'totalPolls': 1,
            'pendingPetitions': 1,
            'resolvedPetitions': 0,
          })),
        ],
        child: const MaterialApp(
          home: CommunityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và tabs
    expect(find.text('Cộng Đồng & Biểu Quyết'), findsOneWidget);
    expect(find.text('Biểu Quyết'), findsOneWidget);
    expect(find.text('Kiến Nghị Cư Dân'), findsOneWidget);

    // 2. Tab 1: Biểu quyết
    expect(find.text('Biểu quyết lựa chọn đơn vị vận hành năm 2027'), findsOneWidget);
    expect(find.text('POLL-202611-00001'), findsOneWidget);
    expect(find.textContaining('Theo diện tích m²'), findsOneWidget);

    // 3. Chuyển sang Tab 2: Kiến nghị
    await tester.tap(find.text('Kiến Nghị Cư Dân'));
    await tester.pumpAndSettle();

    expect(find.text('Đề xuất lắp thêm camera hành lang tầng 5'), findsOneWidget);
    expect(find.text('A0502'), findsOneWidget);
    expect(find.textContaining('12 đồng thuận'), findsOneWidget);
  });
}

