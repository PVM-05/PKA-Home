import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/issue_model.dart';

void main() {
  group('IssueModel Smart Triage Tests', () {
    test('Khởi tạo và parse fromJson đầy đủ thông tin AI Triage và Hazard', () {
      final json = {
        'id': 'issue-101',
        'apartment_id': 'apt-1',
        'reporter_id': 'user-1',
        'assigned_staff_id': 'staff-1',
        'category': 'electrical',
        'priority': 'high',
        'description': 'Ổ cắm điện phòng khách bị chập cháy tóe lửa',
        'status': 'assigned',
        'ai_category_confidence': 0.95,
        'ai_suggested_category': 'electrical',
        'ai_suggested_priority': 'high',
        'ai_triage_reason': 'Phát hiện tình huống nguy hiểm khẩn cấp (chập điện).',
        'is_hazardous': true,
        'auto_assigned': true,
        'created_at': '2026-11-03T08:00:00Z',
      };

      final issue = IssueModel.fromJson(json);

      expect(issue.id, 'issue-101');
      expect(issue.category, 'electrical');
      expect(issue.priority, 'high');
      expect(issue.aiCategoryConfidence, 0.95);
      expect(issue.aiSuggestedCategory, 'electrical');
      expect(issue.aiSuggestedPriority, 'high');
      expect(issue.isHazardous, isTrue);
      expect(issue.autoAssigned, isTrue);
      expect(issue.hasAiTriage, isTrue);
      expect(issue.aiSuggestedCategoryDisplayName, contains('Điện'));
      expect(issue.aiSuggestedPriorityDisplayName, contains('Khẩn cấp'));
    });

    test('toJson và copyWith giữ nguyên vẹn các trường AI Triage', () {
      final issue = IssueModel(
        id: 'issue-102',
        apartmentId: 'apt-2',
        reporterId: 'user-2',
        description: 'Vỡ ống nước',
        status: 'reported',
        priority: 'low',
        category: 'other',
        createdAt: DateTime(2026, 11, 3),
      );

      final updated = issue.copyWith(
        aiCategoryConfidence: 0.88,
        aiSuggestedCategory: 'plumbing',
        aiSuggestedPriority: 'high',
        aiTriageReason: 'Vỡ ống nước ngập nhà',
        isHazardous: true,
        autoAssigned: true,
      );

      expect(updated.isHazardous, isTrue);
      expect(updated.autoAssigned, isTrue);
      expect(updated.aiSuggestedCategory, 'plumbing');

      final json = updated.toJson();
      expect(json['ai_category_confidence'], 0.88);
      expect(json['ai_suggested_category'], 'plumbing');
      expect(json['is_hazardous'], isTrue);
      expect(json['auto_assigned'], isTrue);
    });
  });
}
