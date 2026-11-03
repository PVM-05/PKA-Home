import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/petition_model.dart';

void main() {
  group('PetitionModel Tests (D7)', () {
    final now = DateTime.now();

    test('PetitionModel fromJson parses and formats correctly', () {
      final json = {
        'id': 'pet-01',
        'petition_code': 'PET-202611-00001',
        'apartment_id': 'apt-01',
        'author_user_id': 'usr-01',
        'title': 'Đề xuất lắp thêm camera hành lang tầng 5 tháp A',
        'content': 'Khu vực hành lang tầng 5 góc khuất chưa có camera an ninh, đề nghị BQL khảo sát lắp bổ sung.',
        'category': 'security',
        'image_urls': ['https://example.com/cam1.jpg'],
        'endorsement_count': 18,
        'status': 'in_progress',
        'official_response': 'BQL đã tiếp nhận và đang lập dự toán trình BQT phê duyệt trong tuần tới.',
        'responded_by_staff_id': 'usr-staff-01',
        'responded_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'apartments': {
          'code': 'A0502',
        },
      };

      final petition = PetitionModel.fromJson(json);

      expect(petition.id, equals('pet-01'));
      expect(petition.petitionCode, equals('PET-202611-00001'));
      expect(petition.apartmentCode, equals('A0502'));
      expect(petition.categoryDisplayName, equals('An ninh & Trật tự'));
      expect(petition.statusDisplayName, equals('Đang xử lý'));
      expect(petition.endorsementCount, equals(18));
      expect(petition.officialResponse, contains('BQL đã tiếp nhận'));
    });

    test('PetitionModel copyWith updates fields correctly', () {
      final petition = PetitionModel(
        id: 'pet-01',
        petitionCode: 'PET-202611-00001',
        apartmentId: 'apt-01',
        authorUserId: 'usr-01',
        title: 'Đề xuất camera',
        content: 'Nội dung',
        endorsementCount: 5,
        status: 'pending',
        createdAt: now,
      );

      final updated = petition.copyWith(
        endorsementCount: 6,
        status: 'resolved',
        officialResponse: 'Đã hoàn thành thi công lắp đặt',
      );

      expect(updated.endorsementCount, equals(6));
      expect(updated.status, equals('resolved'));
      expect(updated.statusDisplayName, equals('Đã giải quyết'));
      expect(updated.officialResponse, equals('Đã hoàn thành thi công lắp đặt'));
    });
  });
}

