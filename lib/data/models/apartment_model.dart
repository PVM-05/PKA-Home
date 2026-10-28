class ApartmentModel {
  final String id;
  final String code;
  final String buildingCode;
  final int floorNumber;
  final double? area;
  final bool isEmpty;
  final double electricReading;
  final double waterReading;
  final String? buildingId;
  final double? rentPrice;
  final double? depositAmount;
  final int? maxOccupants;
  final bool hasOwnElectricMeter;
  final bool hasOwnWaterMeter;
  final String? contractStartDate;
  final String? contractEndDate;

  ApartmentModel({
    required this.id,
    required this.code,
    required this.buildingCode,
    required this.floorNumber,
    this.area,
    this.isEmpty = true,
    this.electricReading = 0,
    this.waterReading = 0,
    this.buildingId,
    this.rentPrice,
    this.depositAmount,
    this.maxOccupants,
    this.hasOwnElectricMeter = true,
    this.hasOwnWaterMeter = false,
    this.contractStartDate,
    this.contractEndDate,
  });

  factory ApartmentModel.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    final block = json['block'] as String?;
    final buildingCode = (json['building_code'] as String?) ??
        block ??
        (code.isNotEmpty ? code.substring(0, 1).toUpperCase() : '');
    final floor = json['floor'] as int?;
    final floorNumber = (json['floor_number'] as int?) ??
        floor ??
        (code.length >= 3 ? int.tryParse(code.substring(1, 3)) ?? 1 : 1);

    return ApartmentModel(
      id: json['id'] as String? ?? '',
      code: code,
      buildingCode: buildingCode,
      floorNumber: floorNumber,
      area: json['area'] != null ? (json['area'] as num).toDouble() : null,
      isEmpty: json['is_empty'] as bool? ?? true,
      electricReading: json['electric_reading'] != null ? (json['electric_reading'] as num).toDouble() : 0,
      waterReading: json['water_reading'] != null ? (json['water_reading'] as num).toDouble() : 0,
      buildingId: json['building_id'] as String?,
      rentPrice: json['rent_price'] != null ? (json['rent_price'] as num).toDouble() : null,
      depositAmount: json['deposit_amount'] != null ? (json['deposit_amount'] as num).toDouble() : null,
      maxOccupants: json['max_occupants'] as int?,
      hasOwnElectricMeter: json['has_own_electric_meter'] as bool? ?? true,
      hasOwnWaterMeter: json['has_own_water_meter'] as bool? ?? false,
      contractStartDate: json['contract_start_date'] as String?,
      contractEndDate: json['contract_end_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'building_code': buildingCode,
      'floor_number': floorNumber,
      'area': area,
      'is_empty': isEmpty,
      'electric_reading': electricReading,
      'water_reading': waterReading,
      if (buildingId != null) 'building_id': buildingId,
      if (rentPrice != null) 'rent_price': rentPrice,
      if (depositAmount != null) 'deposit_amount': depositAmount,
      if (maxOccupants != null) 'max_occupants': maxOccupants,
      'has_own_electric_meter': hasOwnElectricMeter,
      'has_own_water_meter': hasOwnWaterMeter,
      if (contractStartDate != null) 'contract_start_date': contractStartDate,
      if (contractEndDate != null) 'contract_end_date': contractEndDate,
    };
  }

  ApartmentModel copyWith({
    String? id,
    String? code,
    String? buildingCode,
    int? floorNumber,
    double? area,
    bool? isEmpty,
    double? electricReading,
    double? waterReading,
    String? buildingId,
    double? rentPrice,
    double? depositAmount,
    int? maxOccupants,
    bool? hasOwnElectricMeter,
    bool? hasOwnWaterMeter,
    String? contractStartDate,
    String? contractEndDate,
  }) {
    return ApartmentModel(
      id: id ?? this.id,
      code: code ?? this.code,
      buildingCode: buildingCode ?? this.buildingCode,
      floorNumber: floorNumber ?? this.floorNumber,
      area: area ?? this.area,
      isEmpty: isEmpty ?? this.isEmpty,
      electricReading: electricReading ?? this.electricReading,
      waterReading: waterReading ?? this.waterReading,
      buildingId: buildingId ?? this.buildingId,
      rentPrice: rentPrice ?? this.rentPrice,
      depositAmount: depositAmount ?? this.depositAmount,
      maxOccupants: maxOccupants ?? this.maxOccupants,
      hasOwnElectricMeter: hasOwnElectricMeter ?? this.hasOwnElectricMeter,
      hasOwnWaterMeter: hasOwnWaterMeter ?? this.hasOwnWaterMeter,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
    );
  }
}
