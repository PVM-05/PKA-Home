import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/issue_smart_triage_engine.dart';

void main() {
  group('IssueSmartTriageEngine Unit Tests', () {
    test('Nhận diện sự cố chập cháy điện khẩn cấp và cảnh báo nguy hiểm', () {
      const description = 'Ổ cắm điện phòng khách bị chập tóe lửa, có mùi khét lẹt và khói đen bốc lên';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'electrical');
      expect(result.priority, 'high');
      expect(result.isHazardous, isTrue);
      expect(result.confidence, greaterThanOrEqualTo(0.8));
      expect(result.hazardAlertMessage, contains('nguy hiểm'));
      expect(result.suggestedStaffRole, contains('Điện'));
    });

    test('Nhận diện sự cố vỡ ống nước ngập nhà mức độ khẩn cấp', () {
      const description = 'Ống nước dưới bồn rửa chén bị vỡ toác, nước tràn lênh láng ngập toàn bộ sàn gỗ';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'plumbing');
      expect(result.priority, 'high');
      expect(result.confidence, greaterThanOrEqualTo(0.8));
      expect(result.suggestedStaffRole, contains('nước'));
    });

    test('Nhận diện kẹt thang máy có người bên trong mức độ khẩn cấp', () {
      const description = 'Thang máy số 2 bị kẹt cứng giữa tầng 10 và 11, đang có 2 người bị kẹt bên trong';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'elevator');
      expect(result.priority, 'high');
      expect(result.isHazardous, isTrue);
      expect(result.suggestedStaffRole, contains('Thang máy'));
    });

    test('Nhận diện chuông báo cháy hoặc rò rỉ khí gas khẩn cấp', () {
      const description = 'Hành lang tầng 8 có mùi xì gas nồng nặc và chuông báo cháy kêu liên hồi';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'fire_safety');
      expect(result.priority, 'high');
      expect(result.isHazardous, isTrue);
      expect(result.suggestedStaffRole, contains('PCCC'));
    });

    test('Nhận diện sự cố thấm dột nứt tường mức độ thường', () {
      const description = 'Góc trần phòng ngủ bị thấm ố vàng và có vết nứt nhỏ sơn bong tróc';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'construction');
      expect(result.priority, 'low');
      expect(result.isHazardous, isFalse);
    });

    test('Nhận diện bóng đèn hành lang bị cháy mức độ thường', () {
      const description = 'Bóng đèn tuýp trước cửa căn hộ bị cháy đen không sáng';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'electrical');
      expect(result.priority, 'low');
      expect(result.isHazardous, isFalse);
    });

    test('Xử lý văn bản trống hoặc không có từ khóa nhận diện', () {
      const description = 'Cần gặp ban quản lý';
      final result = IssueSmartTriageEngine.triage(description);

      expect(result.category, 'other');
      expect(result.priority, 'low');
      expect(result.confidence, lessThan(0.5));
    });
  });
}

