enum BatchImportType {
  apartments,
  residents,
  meterReadings;

  String get label {
    switch (this) {
      case BatchImportType.apartments:
        return 'Căn hộ';
      case BatchImportType.residents:
        return 'Cư dân';
      case BatchImportType.meterReadings:
        return 'Điện nước';
    }
  }

  String get title {
    switch (this) {
      case BatchImportType.apartments:
        return 'Nhập dữ liệu căn hộ';
      case BatchImportType.residents:
        return 'Nhập danh sách cư dân';
      case BatchImportType.meterReadings:
        return 'Nhập chỉ số điện nước';
    }
  }

  String get fileNamePrefix {
    switch (this) {
      case BatchImportType.apartments:
        return 'Mau_Nhap_Can_Ho';
      case BatchImportType.residents:
        return 'Mau_Nhap_Cu_Dan';
      case BatchImportType.meterReadings:
        return 'Mau_Nhap_Chi_So_Dien_Nuoc';
    }
  }
}

class BatchRowErrorModel {
  final int rowNumber;
  final String columnName;
  final String invalidValue;
  final String errorMessage;

  const BatchRowErrorModel({
    required this.rowNumber,
    required this.columnName,
    required this.invalidValue,
    required this.errorMessage,
  });

  String get displayText =>
      'Dòng $rowNumber [$columnName]: $errorMessage (Giá trị: "$invalidValue")';

  Map<String, dynamic> toJson() {
    return {
      'row_number': rowNumber,
      'column_name': columnName,
      'invalid_value': invalidValue,
      'error_message': errorMessage,
    };
  }
}

class ApartmentImportItem {
  final String code;
  final double area;
  final bool isEmpty;
  final String block;
  final int floor;

  ApartmentImportItem({
    required this.code,
    required this.area,
    this.isEmpty = true,
    String? block,
    int? floor,
  })  : block = block ?? _extractBlock(code),
        floor = floor ?? _extractFloor(code);

  static String _extractBlock(String code) {
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(code.trim());
    return match != null ? match.group(1)!.toUpperCase() : 'A';
  }

  static int _extractFloor(String code) {
    final match = RegExp(r'^[A-Za-z]+([0-9]{2})').firstMatch(code.trim());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'area': area,
      'is_empty': isEmpty,
      'block': block,
      'floor': floor,
    };
  }
}

class ResidentImportItem {
  final String apartmentCode;
  final String fullName;
  final String phone;
  final String relationRole;
  final String? email;

  const ResidentImportItem({
    required this.apartmentCode,
    required this.fullName,
    required this.phone,
    this.relationRole = 'resident',
    this.email,
  });

  String get relationRoleText {
    switch (relationRole.toLowerCase().trim()) {
      case 'owner':
        return 'Chủ hộ';
      case 'tenant':
        return 'Người thuê';
      case 'family_member':
        return 'Thành viên gia đình';
      case 'resident':
      default:
        return 'Cư dân';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'apartment_code': apartmentCode,
      'full_name': fullName,
      'phone': phone,
      'relation_role': relationRole,
      if (email != null && email!.isNotEmpty) 'email': email,
    };
  }
}

class MeterReadingImportItem {
  final String apartmentCode;
  final double electricReading;
  final double waterReading;
  final String? period;

  const MeterReadingImportItem({
    required this.apartmentCode,
    required this.electricReading,
    required this.waterReading,
    this.period,
  });

  Map<String, dynamic> toJson() {
    return {
      'apartment_code': apartmentCode,
      'electric_reading': electricReading,
      'water_reading': waterReading,
      if (period != null) 'period': period,
    };
  }
}

class BatchImportResultModel<T> {
  final int totalRows;
  final List<T> validItems;
  final List<BatchRowErrorModel> rowErrors;

  const BatchImportResultModel({
    required this.totalRows,
    required this.validItems,
    required this.rowErrors,
  });

  int get validCount => validItems.length;
  int get errorCount => rowErrors.length;
  bool get hasValidItems => validItems.isNotEmpty;
  bool get hasErrors => rowErrors.isNotEmpty;
  bool get isAllValid => errorCount == 0 && totalRows > 0;
}
