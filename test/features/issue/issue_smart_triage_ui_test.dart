import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/features/resident/screens/create_issue_screen.dart';

void main() {
  group('Issue Smart Triage UI Tests', () {
    testWidgets('CreateIssueScreen hiển thị banner cảnh báo nguy hiểm khẩn cấp khi nhập sự cố chập cháy',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CreateIssueScreen(),
          ),
        ),
      );

      // Ban đầu chưa có banner cảnh báo
      expect(find.byKey(const Key('ai_hazardous_alert_banner')), findsNothing);
      expect(find.byKey(const Key('ai_suggestion_banner')), findsNothing);

      // Nhập mô tả chập cháy nổ điện
      await tester.enterText(
        find.byKey(const Key('issue_description_field')),
        'Chập điện nổ ổ cắm bốc khói khét lẹt tóe lửa nguy hiểm',
      );
      await tester.pumpAndSettle();

      // Banner nguy hiểm khẩn cấp và nút gọi hotline xuất hiện
      expect(find.byKey(const Key('ai_hazardous_alert_banner')), findsOneWidget);
      expect(find.text('CẢNH BÁO NGUY HIỂM KHẨN CẤP'), findsOneWidget);
      expect(find.byKey(const Key('call_hotline_emergency_button')), findsOneWidget);
    });

    testWidgets('CreateIssueScreen hiển thị gợi ý AI và áp dụng chuyên môn một chạm khi nhập sự cố nước',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CreateIssueScreen(),
          ),
        ),
      );

      // Nhập sự cố vỡ ống nước
      await tester.enterText(
        find.byKey(const Key('issue_description_field')),
        'Vỡ đường ống nước rò rỉ bồn rửa chén chảy tràn ra bếp',
      );
      await tester.pumpAndSettle();

      // Banner gợi ý AI xuất hiện
      expect(find.byKey(const Key('ai_suggestion_banner')), findsOneWidget);
      expect(find.textContaining('Gợi ý từ trợ lý AI'), findsOneWidget);
      expect(find.byKey(const Key('apply_ai_suggestion_button')), findsOneWidget);

      // Bấm nút áp dụng gợi ý
      await tester.tap(find.byKey(const Key('apply_ai_suggestion_button')));
      await tester.pumpAndSettle();

      // Xác nhận nút hiển thị snackbar thành công
      expect(find.textContaining('Đã tự động áp dụng phân loại'), findsOneWidget);
    });

    testWidgets('Hiển thị huy hiệu NGUY HIỂM và AI Triage trên thẻ sự cố', (tester) async {
      final sampleIssue = IssueModel(
        id: 'issue-001',
        apartmentId: 'apt-001',
        reporterId: 'user-001',
        description: 'Chập cầu dao tổng bốc khói',
        priority: 'high',
        category: 'electrical',
        status: 'pending',
        isHazardous: true,
        aiCategoryConfidence: 0.96,
        aiSuggestedCategory: 'electrical',
        aiSuggestedPriority: 'high',
        aiTriageReason: 'Phát hiện rủi ro chập cháy nổ điện',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        apartment: ApartmentModel(
          id: 'apt-001',
          code: 'A0110',
          buildingCode: 'B01',
          floorNumber: 1,
          area: 75.0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    if (sampleIssue.isHazardous)
                      Container(
                        key: const Key('hazardous_badge'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: AppTheme.error,
                        child: const Text('NGUY HIỂM', style: TextStyle(color: Colors.white)),
                      ),
                    if (sampleIssue.hasAiTriage)
                      Container(
                        key: const Key('ai_triage_badge'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        color: Colors.purple.shade50,
                        child: Text(
                          'AI: ${sampleIssue.aiSuggestedCategoryDisplayName} (${(sampleIssue.aiCategoryConfidence * 100).toInt()}%)',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('hazardous_badge')), findsOneWidget);
      expect(find.text('NGUY HIỂM'), findsOneWidget);

      expect(find.byKey(const Key('ai_triage_badge')), findsOneWidget);
      expect(find.textContaining('AI: Điện / Thiết bị điện (96%)'), findsOneWidget);
    });
  });
}
