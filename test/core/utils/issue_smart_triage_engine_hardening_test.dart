import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/issue_smart_triage_engine.dart';

void main() {
  group('IssueSmartTriageEngine Hardening Tests (P0)', () {
    test('Câu chứa từ "nóng" không bị gắn cờ nguy hiểm do substring "no"', () {
      final result = IssueSmartTriageEngine.triage(
        'Bồn cầu bị tắc, thời tiết hôm nay rất nóng bức',
      );

      expect(result.isHazardous, isFalse,
          reason: 'Từ "nóng" không được khớp nhầm với từ khóa "no"');
      expect(result.category, equals('plumbing'));
    });

    test('Câu gõ không dấu "bon cau bi tac, nong" không bị gắn cờ nguy hiểm', () {
      final result = IssueSmartTriageEngine.triage(
        'bon cau bi tac, nong',
      );

      expect(result.isHazardous, isFalse,
          reason: 'Từ không dấu "nong" không được khớp nhầm với từ khóa "no"');
    });

    test('Câu chứa từ "chạy" không bị gắn cờ hỏa hoạn do substring "chay"', () {
      final result = IssueSmartTriageEngine.triage(
        'Máy bơm đang chạy liên tục không ngắt',
      );

      expect(result.isHazardous, isFalse,
          reason: 'Từ "chạy" không được khớp nhầm với hỏa hoạn');
    });

    test('Phát hiện sự cố rò rỉ mùi gas gắn cờ nguy hiểm khẩn cấp chính xác', () {
      final result = IssueSmartTriageEngine.triage(
        'Phát hiện có mùi gas rất nồng nặc tại tầng 7',
      );

      expect(result.isHazardous, isTrue);
      expect(result.priority, equals('high'));
    });

    test('Phát hiện hỏa hoạn / cháy nhà gắn cờ nguy hiểm khẩn cấp chính xác', () {
      final result = IssueSmartTriageEngine.triage(
        'Đám cháy bùng phát tại phòng kỹ thuật tầng 3',
      );

      expect(result.isHazardous, isTrue);
      expect(result.priority, equals('high'));
      expect(result.category, equals('fire_safety'));
    });

    test('Phát hiện kẹt thang máy có người gắn cờ nguy hiểm khẩn cấp chính xác', () {
      final result = IssueSmartTriageEngine.triage(
        'Kẹt thang máy số 2, đang có 3 người mắc kẹt bên trong',
      );

      expect(result.isHazardous, isTrue);
      expect(result.priority, equals('high'));
      expect(result.category, equals('elevator'));
    });
  });
}
