import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/issue_sla_stats_model.dart';
import 'package:pka_home/data/models/issue_model.dart';

void main() {
  group('IssueSlaStatsModel Tests', () {
    final jsonSample = {
      'total_issues': 20,
      'on_time_count': 16,
      'warning_count': 2,
      'breached_count': 2,
      'compliance_rate': 90.0,
    };

    test('fromJson parses SLA stats accurately', () {
      final model = IssueSlaStatsModel.fromJson(jsonSample);

      expect(model.totalIssues, 20);
      expect(model.onTimeCount, 16);
      expect(model.warningCount, 2);
      expect(model.breachedCount, 2);
      expect(model.complianceRate, 90.0);
      expect(model.complianceRateFormatted, '90.0%');
    });

    test('IssueModel SLA logic getters work properly', () {
      final now = DateTime.now();

      // Trường hợp 1: Còn nhiều thời gian (> 2h)
      final issueOnTime = IssueModel(
        id: 'iss-01',
        apartmentId: 'apt-01',
        reporterId: 'usr-01',
        description: 'Cháy bóng đèn',
        status: 'pending',
        priority: 'medium',
        category: 'electrical',
        createdAt: now.subtract(const Duration(hours: 1)),
        slaDeadline: now.add(const Duration(hours: 23)),
      );

      expect(issueOnTime.isSlaBreached, isFalse);
      expect(issueOnTime.isSlaWarning, isFalse);
      expect(issueOnTime.categoryDisplayName, 'Điện');
      expect(issueOnTime.slaRemainingFormatted, contains('Còn'));

      // Trường hợp 2: Sắp trễ (< 2h)
      final issueWarning = IssueModel(
        id: 'iss-02',
        apartmentId: 'apt-01',
        reporterId: 'usr-01',
        description: 'Vỡ ống nước',
        status: 'in_progress',
        priority: 'high',
        category: 'plumbing',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 15)),
        slaDeadline: now.add(const Duration(minutes: 45)),
      );

      expect(issueWarning.isSlaWarning, isTrue);
      expect(issueWarning.isSlaBreached, isFalse);
      expect(issueWarning.categoryDisplayName, 'Nước');

      // Trường hợp 3: Đã trễ hạn (deadline ở quá khứ)
      final issueBreached = IssueModel(
        id: 'iss-03',
        apartmentId: 'apt-01',
        reporterId: 'usr-01',
        description: 'Kẹt cửa thoát hiểm',
        status: 'in_progress',
        priority: 'high',
        category: 'fire_safety',
        createdAt: now.subtract(const Duration(hours: 5)),
        slaDeadline: now.subtract(const Duration(hours: 3)),
      );

      expect(issueBreached.isSlaBreached, isTrue);
      expect(issueBreached.categoryDisplayName, 'PCCC & An toàn');
      expect(issueBreached.slaRemainingFormatted, contains('Trễ'));
    });
  });
}

