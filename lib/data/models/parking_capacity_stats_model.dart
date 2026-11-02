class ParkingCapacityStatsModel {
  final int carTotal;
  final int carOccupied;
  final int carAvailable;
  final int motoTotal;
  final int motoOccupied;
  final int motoAvailable;
  final int visitorCount;

  ParkingCapacityStatsModel({
    required this.carTotal,
    required this.carOccupied,
    required this.carAvailable,
    required this.motoTotal,
    required this.motoOccupied,
    required this.motoAvailable,
    required this.visitorCount,
  });

  double get carOccupancyRate {
    if (carTotal <= 0) return 0.0;
    return (carOccupied / carTotal) * 100.0;
  }

  double get motoOccupancyRate {
    if (motoTotal <= 0) return 0.0;
    return (motoOccupied / motoTotal) * 100.0;
  }

  factory ParkingCapacityStatsModel.fromJson(Map<String, dynamic> json) {
    return ParkingCapacityStatsModel(
      carTotal: (json['car_total'] as num?)?.toInt() ?? 0,
      carOccupied: (json['car_occupied'] as num?)?.toInt() ?? 0,
      carAvailable: (json['car_available'] as num?)?.toInt() ?? 0,
      motoTotal: (json['moto_total'] as num?)?.toInt() ?? 0,
      motoOccupied: (json['moto_occupied'] as num?)?.toInt() ?? 0,
      motoAvailable: (json['moto_available'] as num?)?.toInt() ?? 0,
      visitorCount: (json['visitor_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'car_total': carTotal,
      'car_occupied': carOccupied,
      'car_available': carAvailable,
      'moto_total': motoTotal,
      'moto_occupied': motoOccupied,
      'moto_available': motoAvailable,
      'visitor_count': visitorCount,
    };
  }

  factory ParkingCapacityStatsModel.empty() {
    return ParkingCapacityStatsModel(
      carTotal: 0,
      carOccupied: 0,
      carAvailable: 0,
      motoTotal: 0,
      motoOccupied: 0,
      motoAvailable: 0,
      visitorCount: 0,
    );
  }
}
