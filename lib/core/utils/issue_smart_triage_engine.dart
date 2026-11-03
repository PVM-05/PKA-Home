class IssueTriageResult {
  final String category; // 'electrical', 'plumbing', 'construction', 'elevator', 'fire_safety', 'other'
  final String priority; // 'high', 'medium', 'low'
  final double confidence; // 0.0 - 1.0
  final bool isHazardous;
  final String reason;
  final String suggestedStaffRole;
  final String? hazardAlertMessage;

  const IssueTriageResult({
    required this.category,
    required this.priority,
    required this.confidence,
    required this.isHazardous,
    required this.reason,
    required this.suggestedStaffRole,
    this.hazardAlertMessage,
  });

  String get categoryDisplayName {
    switch (category) {
      case 'electrical':
        return 'Điện / Thiết bị điện';
      case 'plumbing':
        return 'Nước / Cấp thoát nước';
      case 'elevator':
        return 'Thang máy';
      case 'fire_safety':
        return 'PCCC & An toàn';
      case 'construction':
        return 'Xây dựng / Hoàn thiện';
      case 'other':
      default:
        return 'Sự cố khác';
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case 'high':
        return 'Khẩn cấp (2h)';
      case 'medium':
        return 'Ưu tiên (24h)';
      case 'low':
      default:
        return 'Thường (72h)';
    }
  }

  Duration get recommendedSlaDuration {
    switch (priority) {
      case 'high':
        return const Duration(hours: 2);
      case 'medium':
        return const Duration(hours: 24);
      case 'low':
      default:
        return const Duration(hours: 72);
    }
  }
}

class IssueSmartTriageEngine {
  IssueSmartTriageEngine._();

  static const List<String> _hazardousKeywords = [
    'nổ',
    'no',
    'khói',
    'khoi',
    'mùi khét',
    'khet',
    'xì gas',
    'xi gas',
    'rò gas',
    'ro gas',
    'khí gas',
    'giật điện',
    'giat dien',
    'chập tóe lửa',
    'chập điện',
    'chap dien',
    'vỡ ống nước',
    'vo ong nuoc',
    'tràn lênh láng ngập',
    'ngập nhà',
    'rơi thang',
    'sập trần',
  ];

  static const Map<String, List<String>> _categoryKeywords = {
    'fire_safety': [
      'cháy',
      'chay',
      'khói',
      'khoi',
      'mùi khét',
      'khet',
      'chuông báo cháy',
      'báo cháy',
      'bao chay',
      'pccc',
      'cứu hỏa',
      'cuu hoa',
      'bình chữa cháy',
      'binh chua chay',
      'xì gas',
      'rò gas',
      'khí gas',
      'báo khói',
      'cửa thoát hiểm',
    ],
    'elevator': [
      'thang máy',
      'thang may',
      'kẹt thang',
      'ket thang',
      'rơi thang',
      'thang đứng im',
      'cửa thang',
      'thẻ thang',
      'bảng điều khiển thang',
      'rung lắc thang',
      'buồng thang',
    ],
    'electrical': [
      'bóng đèn',
      'bong den',
      'cháy bóng',
      'chay bong',
      'đèn bị cháy',
      'bóng tuýp',
      'đèn led',
      'ổ cắm',
      'o cam',
      'công tắc',
      'cong tac',
      'chập',
      'chap',
      'attomat',
      'aptomat',
      'mất điện',
      'mat dien',
      'nhảy cb',
      'nhay cb',
      'cầu dao',
      'cau dao',
      'dây điện',
      'day dien',
      'tủ điện',
      'tu dien',
      'rò điện',
      'ro dien',
      'đoản mạch',
      'cầu chì',
      'sập nguồn',
      'điện',
      'dien',
    ],
    'plumbing': [
      'nước',
      'nuoc',
      'rò rỉ',
      'ro ri',
      'vòi sen',
      'voi sen',
      'bồn cầu',
      'bon cau',
      'bồn rửa',
      'bon rua',
      'ống nước',
      'ong nuoc',
      'rỉ nước',
      'ri nuoc',
      'tắc cống',
      'tac cong',
      'nghẹt cống',
      'vỡ ống',
      'vo ong',
      'mất nước',
      'mat nuoc',
      'ngập',
      'ngap',
      'phao nước',
      'van nước',
      'bể nước',
      'áp lực yếu',
    ],
    'construction': [
      'nứt tường',
      'nut tuong',
      'nứt',
      'nut',
      'thấm trần',
      'tham tran',
      'thấm',
      'tham',
      'dột',
      'dot',
      'ố vàng',
      'sơn bả',
      'bong tróc',
      'bong troc',
      'rơi gạch',
      'gạch ốp',
      'ổ khóa',
      'o khoa',
      'khóa cửa',
      'tay nắm',
      'bản lề',
      'ban le',
      'cửa hỏng',
      'sàn gỗ',
      'vỡ kính',
      'lan can',
      'ban công',
    ],
  };

  /// Phân tích nội dung mô tả sự cố để trích xuất danh mục, mức độ khẩn cấp và đề xuất KTV
  static IssueTriageResult triage(String description) {
    final lower = description.toLowerCase().trim();
    if (lower.isEmpty) {
      return const IssueTriageResult(
        category: 'other',
        priority: 'low',
        confidence: 0.1,
        isHazardous: false,
        reason: 'Nội dung mô tả trống.',
        suggestedStaffRole: 'Ban Quản Lý Tòa Nhà',
      );
    }

    // Kiểm tra xem chữ "cháy" có phải là cháy bóng đèn thông thường hay không
    final isLampBurnout = lower.contains('cháy bóng') ||
        lower.contains('bóng đèn') && lower.contains('cháy') ||
        lower.contains('đèn bị cháy') ||
        lower.contains('cháy đèn') ||
        lower.contains('cháy led');

    // 1. Kiểm tra dấu hiệu nguy hiểm khẩn cấp (PCCC / Chập nổ / Kẹt thang / Vỡ ống)
    bool isHazardous = false;
    String? matchedHazard;

    final hasElevatorStuck = (lower.contains('thang máy') || lower.contains('thang may') || lower.contains('thang')) &&
        (lower.contains('kẹt') || lower.contains('ket') || lower.contains('rơi') || lower.contains('roi'));

    final hasTrappedPerson = lower.contains('kẹt người') ||
        lower.contains('ket nguoi') ||
        (lower.contains('người') && lower.contains('kẹt')) ||
        (lower.contains('nguoi') && lower.contains('ket'));

    // Nếu có chữ "cháy" nhưng không phải là cháy bóng đèn thì là hỏa hoạn
    if ((lower.contains('cháy') || lower.contains('chay')) && !isLampBurnout) {
      isHazardous = true;
      matchedHazard = 'Hỏa hoạn / Cháy nổ';
    } else if (hasElevatorStuck || hasTrappedPerson) {
      isHazardous = true;
      matchedHazard = 'Kẹt thang máy / Có người mắc kẹt';
    } else {
      for (final kw in _hazardousKeywords) {
        if (lower.contains(kw)) {
          isHazardous = true;
          matchedHazard = kw;
          break;
        }
      }
    }

    // 2. Chấm điểm từng chuyên môn
    final scores = <String, int>{
      'fire_safety': 0,
      'elevator': 0,
      'electrical': 0,
      'plumbing': 0,
      'construction': 0,
    };

    final matchedWords = <String, List<String>>{};

    _categoryKeywords.forEach((cat, kws) {
      matchedWords[cat] = [];
      for (final kw in kws) {
        // Bỏ qua "cháy" trong fire_safety nếu là cháy bóng đèn
        if (cat == 'fire_safety' && (kw == 'cháy' || kw == 'chay') && isLampBurnout) {
          continue;
        }

        if (lower.contains(kw)) {
          final weight = kw.contains(' ') ? 2 : 1;
          scores[cat] = (scores[cat] ?? 0) + weight;
          matchedWords[cat]!.add(kw);
        }
      }
    });

    // Sắp xếp danh mục theo điểm số
    final sortedCats = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final bestEntry = sortedCats.first;

    String selectedCategory = 'other';
    double confidence = 0.3;
    String reason = 'Không tìm thấy từ khóa chuyên môn phù hợp, xếp vào mục Khác.';

    if (bestEntry.value > 0) {
      selectedCategory = bestEntry.key;
      final matched = matchedWords[selectedCategory] ?? [];
      final uniqueMatches = matched.toSet().take(3).join(', ');

      if (bestEntry.value >= 3) {
        confidence = 0.95;
        reason = 'Phát hiện các từ khóa chuyên môn rõ nét: $uniqueMatches.';
      } else if (bestEntry.value >= 2) {
        confidence = 0.85;
        reason = 'Phát hiện từ khóa chuyên môn: $uniqueMatches.';
      } else {
        confidence = 0.70;
        reason = 'Khớp từ khóa: $uniqueMatches.';
      }
    }

    // 3. Quyết định mức độ ưu tiên
    String priority = 'low';
    if (isHazardous) {
      priority = 'high';
      reason += ' Phát hiện tình huống nguy hiểm khẩn cấp ($matchedHazard).';
    } else if (lower.contains('mất nước') ||
        lower.contains('mất điện') ||
        lower.contains('tắc bồn cầu') ||
        lower.contains('ngập') ||
        lower.contains('không vào được nhà') ||
        lower.contains('kẹt khóa')) {
      priority = 'medium';
      reason += ' Ảnh hưởng trực tiếp đến sinh hoạt thiết yếu (Ưu tiên 24h).';
    }

    // 4. Gợi ý bộ phận kỹ thuật viên
    String suggestedStaffRole;
    switch (selectedCategory) {
      case 'fire_safety':
        suggestedStaffRole = 'Đội PCCC & An ninh trực ban';
        break;
      case 'elevator':
        suggestedStaffRole = 'Đội Kỹ thuật & Bảo trì Thang máy';
        break;
      case 'electrical':
        suggestedStaffRole = 'Kỹ thuật Điện / Cơ điện (M&E)';
        break;
      case 'plumbing':
        suggestedStaffRole = 'Kỹ thuật Cấp thoát nước';
        break;
      case 'construction':
        suggestedStaffRole = 'Kỹ thuật Xây dựng & Hoàn thiện';
        break;
      case 'other':
      default:
        suggestedStaffRole = 'Ban Quản Lý Tòa Nhà';
        break;
    }

    String? hazardAlert;
    if (isHazardous) {
      hazardAlert =
          'Tình huống có thể gây nguy hiểm! Vui lòng gọi ngay Hotline Ban Quản Lý và giữ khoảng cách an toàn.';
    }

    return IssueTriageResult(
      category: selectedCategory,
      priority: priority,
      confidence: confidence,
      isHazardous: isHazardous,
      reason: reason,
      suggestedStaffRole: suggestedStaffRole,
      hazardAlertMessage: hazardAlert,
    );
  }
}
