class FrontDeskStatsModel {
  final int expectedVisitorsToday;
  final int visitorsInBuilding;
  final int pendingParcels;
  final int overdueParcels;

  const FrontDeskStatsModel({
    required this.expectedVisitorsToday,
    required this.visitorsInBuilding,
    required this.pendingParcels,
    required this.overdueParcels,
  });

  factory FrontDeskStatsModel.fromJson(Map<String, dynamic> json) {
    return FrontDeskStatsModel(
      expectedVisitorsToday: (json['expected_visitors_today'] as num?)?.toInt() ?? 0,
      visitorsInBuilding: (json['visitors_in_building'] as num?)?.toInt() ?? 0,
      pendingParcels: (json['pending_parcels'] as num?)?.toInt() ?? 0,
      overdueParcels: (json['overdue_parcels'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expected_visitors_today': expectedVisitorsToday,
      'visitors_in_building': visitorsInBuilding,
      'pending_parcels': pendingParcels,
      'overdue_parcels': overdueParcels,
    };
  }
}

