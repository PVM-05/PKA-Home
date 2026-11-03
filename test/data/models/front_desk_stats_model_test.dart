import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/front_desk_stats_model.dart';

void main() {
  group('FrontDeskStatsModel Tests', () {
    final sampleJson = {
      'expected_visitors_today': 12,
      'visitors_in_building': 4,
      'pending_parcels': 25,
      'overdue_parcels': 3,
    };

    test('fromJson parses data correctly', () {
      final model = FrontDeskStatsModel.fromJson(sampleJson);

      expect(model.expectedVisitorsToday, 12);
      expect(model.visitorsInBuilding, 4);
      expect(model.pendingParcels, 25);
      expect(model.overdueParcels, 3);
    });

    test('toJson serializes correctly', () {
      final model = FrontDeskStatsModel.fromJson(sampleJson);
      final json = model.toJson();

      expect(json['expected_visitors_today'], 12);
      expect(json['visitors_in_building'], 4);
      expect(json['pending_parcels'], 25);
      expect(json['overdue_parcels'], 3);
    });
  });
}

