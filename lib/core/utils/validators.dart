// Tập hợp các hàm validate dùng chung trong ứng dụng.
//
// Được sử dụng với [TextFormField.validator] để kiểm tra dữ liệu
// nhập vào theo các quy chuẩn đặt ra trong `database-rules.md`.

/// Validate mã căn hộ / phòng trọ.
///
/// Hỗ trợ cả định dạng chung cư chuẩn (`<Block chữ cái><Tầng 2 số><Phòng 2 số>`, VD: A0110, b0512)
/// lẫn định dạng phòng trọ linh hoạt (VD: P101, 101, Phòng 3, P-201, T2-05).
///
/// Nếu [strictApartmentFormat] là `true`, bắt buộc tuân theo định dạng chung cư `A0110`.
String? validateApartmentCode(
  String? value, {
  bool strictApartmentFormat = false,
}) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập mã căn hộ';
  }

  final trimmed = value.trim();

  if (strictApartmentFormat) {
    // Regex: 1 chữ cái + 4 chữ số (VD: A0110, b0512)
    final pattern = RegExp(r'^[A-Za-z]\d{4}$');
    if (!pattern.hasMatch(trimmed)) {
      return 'Mã căn hộ phải có dạng: 1 chữ cái + 4 chữ số (VD: A0110)';
    }

    final floor = int.tryParse(trimmed.substring(1, 3)) ?? 0;
    if (floor <= 0) {
      return 'Số tầng phải lớn hơn 0 (VD: A0110 = Tầng 01)';
    }

    final room = int.tryParse(trimmed.substring(3, 5)) ?? 0;
    if (room <= 0) {
      return 'Số phòng phải lớn hơn 0 (VD: A0110 = Phòng 10)';
    }

    return null;
  }

  // Chế độ linh hoạt cho phòng trọ / căn hộ chung:
  // Nếu người dùng nhập định dạng A0110 thì vẫn kiểm tra tính hợp lệ của tầng/phòng
  final standardApartmentPattern = RegExp(r'^[A-Za-z]\d{4}$');
  if (standardApartmentPattern.hasMatch(trimmed)) {
    final floor = int.tryParse(trimmed.substring(1, 3)) ?? 0;
    if (floor <= 0) {
      return 'Số tầng phải lớn hơn 0 (VD: A0110 = Tầng 01)';
    }
    final room = int.tryParse(trimmed.substring(3, 5)) ?? 0;
    if (room <= 0) {
      return 'Số phòng phải lớn hơn 0 (VD: A0110 = Phòng 10)';
    }
    return null;
  }

  // Đối với mã phòng tự do (VD: P101, 101, Phòng 3, P-201, T2-05):
  if (trimmed.length > 15) {
    return 'Mã phòng không được vượt quá 15 ký tự';
  }

  final flexiblePattern = RegExp(r'^[A-Za-z0-9À-ỹ\s\-\._]{1,15}$');
  final hasAlphaNum = RegExp(r'[A-Za-z0-9À-ỹ]').hasMatch(trimmed);

  if (!flexiblePattern.hasMatch(trimmed) || !hasAlphaNum) {
    return 'Mã phòng chỉ được chứa chữ cái, số, gạch nối hoặc dấu chấm';
  }

  return null;
}

/// Validate trường bắt buộc không được để trống.
String? validateRequired(String? value, [String fieldName = 'Trường này']) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName không được để trống';
  }
  return null;
}

/// Validate diện tích căn hộ (phải là số dương).
String? validateArea(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập diện tích';
  }

  final area = double.tryParse(value.trim());
  if (area == null || area <= 0) {
    return 'Diện tích phải là số dương (VD: 55.5)';
  }

  if (area > 500) {
    return 'Diện tích không hợp lý (tối đa 500 m²)';
  }

  return null;
}

/// Validate số điện thoại Việt Nam (10 chữ số, bắt đầu bằng 0).
/// Cho phép để trống (optional field).
String? validatePhoneOptional(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null; // Cho phép bỏ trống
  }

  final trimmed = value.trim();
  final pattern = RegExp(r'^0\d{9}$');

  if (!pattern.hasMatch(trimmed)) {
    return 'Số điện thoại phải có 10 chữ số, bắt đầu bằng 0';
  }

  return null;
}

/// Validate số thực không âm (>= 0), ví dụ sản lượng điện, nước tiêu thụ.
String? validateNonNegativeNumber(
  String? value, [
  String fieldName = 'Số lượng',
  bool isRequired = false,
]) {
  if (value == null || value.trim().isEmpty) {
    if (isRequired) return '$fieldName không được để trống';
    return null;
  }

  final num = double.tryParse(value.trim());
  if (num == null) {
    return '$fieldName phải là số hợp lệ';
  }

  if (num < 0) {
    return '$fieldName không được là số âm';
  }

  return null;
}

/// Validate số thực dương (> 0), ví dụ đơn giá tiền điện, nước, quản lý.
String? validatePositiveNumber(
  String? value, [
  String fieldName = 'Đơn giá',
  bool isRequired = true,
]) {
  if (value == null || value.trim().isEmpty) {
    if (isRequired) return '$fieldName không được để trống';
    return null;
  }

  final num = double.tryParse(value.trim());
  if (num == null) {
    return '$fieldName phải là số hợp lệ';
  }

  if (num <= 0) {
    return '$fieldName phải lớn hơn 0';
  }

  return null;
}

/// Validate số nguyên không âm (>= 0), ví dụ số lượng xe máy, ô tô.
String? validateNonNegativeInt(
  String? value, [
  String fieldName = 'Số lượng',
  bool isRequired = false,
]) {
  if (value == null || value.trim().isEmpty) {
    if (isRequired) return '$fieldName không được để trống';
    return null;
  }

  final num = int.tryParse(value.trim());
  if (num == null) {
    return '$fieldName phải là số nguyên hợp lệ';
  }

  if (num < 0) {
    return '$fieldName không được là số âm';
  }

  return null;
}

/// Validate kỳ hóa đơn theo định dạng chuẩn MM/yyyy (VD: 09/2026).
String? validateInvoicePeriod(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Vui lòng nhập kỳ hóa đơn';
  }

  final trimmed = value.trim();
  final pattern = RegExp(r'^(0[1-9]|1[0-2])/\d{4}$');

  if (!pattern.hasMatch(trimmed)) {
    return 'Định dạng kỳ phải là MM/yyyy (VD: 09/2026)';
  }

  return null;
}
