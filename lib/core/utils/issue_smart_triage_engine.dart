class IssueTriageResult {
  final String
  category; // 'electrical', 'plumbing', 'construction', 'elevator', 'fire_safety', 'other'
  final String priority; // 'high', 'medium', 'low'
  final double confidence; // 0.0 - 1.0
  final bool isHazardous;
  final bool isFireHazard;
  final bool isTrappedPersonHazard;
  final String reason;
  final String suggestedStaffRole;
  final String? hazardAlertMessage;
  final List<String> emergencyHotlines;

  const IssueTriageResult({
    required this.category,
    required this.priority,
    required this.confidence,
    required this.isHazardous,
    this.isFireHazard = false,
    this.isTrappedPersonHazard = false,
    required this.reason,
    required this.suggestedStaffRole,
    this.hazardAlertMessage,
    this.emergencyHotlines = const ['02439998888'],
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
    'phát nổ',
    'cháy nổ',
    'khói bốc',
    'mùi khét',
    'xì gas',
    'xi gas',
    'rò gas',
    'ro gas',
    'mùi gas',
    'mui gas',
    'rò rỉ gas',
    'khí gas',
    'giật điện',
    'giat dien',
    'hở điện',
    'chập tóe lửa',
    'chập điện',
    'chap dien',
    'vỡ ống nước',
    'vo ong nuoc',
    'vỡ ống',
    'vo ong',
    'vỡ toác',
    'vỡ đường ống',
    'bục ống',
    'tràn ngập',
    'tràn lênh láng',
    'ngập nhà',
    'ngập sàn',
    'ngập toàn bộ',
    'rơi thang',
    'sập trần',
    'mắc kẹt',
    'mac ket',
  ];

  /// Kiểm tra sự xuất hiện của từ hoặc cụm từ theo ranh giới từ vựng (tránh lỗi substring: 'nóng' khớp 'no')
  static bool _containsWordOrPhrase(String text, String keyword) {
    final pattern = RegExp(
      r'(?:^|[^a-zA-Z0-9àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ])' +
          RegExp.escape(keyword) +
          r'(?:$|[^a-zA-Z0-9àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ])',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  static const Map<String, List<String>> _categoryKeywords = {
    'fire_safety': [
      'cháy',
      'chay nha',
      'dam chay',
      'chay khet',
      'chua chay',
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
    final isLampBurnout =
        lower.contains('cháy bóng') ||
        lower.contains('bóng đèn') && lower.contains('cháy') ||
        lower.contains('đèn bị cháy') ||
        lower.contains('cháy đèn') ||
        lower.contains('cháy led');

    // 1. Kiểm tra dấu hiệu nguy hiểm khẩn cấp (PCCC / Chập nổ / Kẹt thang / Vỡ ống)
    bool isHazardous = false;
    String? matchedHazard;

    final hasElevatorStuck =
        (_containsWordOrPhrase(lower, 'thang máy') ||
            _containsWordOrPhrase(lower, 'thang may') ||
            _containsWordOrPhrase(lower, 'thang')) &&
        (_containsWordOrPhrase(lower, 'kẹt') ||
            _containsWordOrPhrase(lower, 'ket') ||
            _containsWordOrPhrase(lower, 'rơi') ||
            _containsWordOrPhrase(lower, 'roi'));

    final hasTrappedPerson =
        _containsWordOrPhrase(lower, 'kẹt người') ||
        _containsWordOrPhrase(lower, 'ket nguoi') ||
        (_containsWordOrPhrase(lower, 'người') && _containsWordOrPhrase(lower, 'kẹt')) ||
        (_containsWordOrPhrase(lower, 'nguoi') && _containsWordOrPhrase(lower, 'ket')) ||
        _containsWordOrPhrase(lower, 'mắc kẹt') ||
        _containsWordOrPhrase(lower, 'mac ket');

    // Kiểm tra hỏa hoạn: tránh nhầm từ 'chạy' / 'chảy' bằng kiểm tra ranh giới từ
    final isFireHazard =
        (_containsWordOrPhrase(lower, 'cháy') ||
            _containsWordOrPhrase(lower, 'hỏa hoạn') ||
            _containsWordOrPhrase(lower, 'hoa hoan') ||
            _containsWordOrPhrase(lower, 'đám cháy') ||
            _containsWordOrPhrase(lower, 'dam chay') ||
            _containsWordOrPhrase(lower, 'bốc cháy') ||
            _containsWordOrPhrase(lower, 'chay nha') ||
            _containsWordOrPhrase(lower, 'cháy nổ') ||
            _containsWordOrPhrase(lower, 'chập cháy')) &&
        !isLampBurnout;

    if (isFireHazard) {
      isHazardous = true;
      matchedHazard = 'Hỏa hoạn / Cháy nổ';
    } else if (hasElevatorStuck || hasTrappedPerson) {
      isHazardous = true;
      matchedHazard = 'Kẹt thang máy / Có người mắc kẹt';
    } else {
      for (final kw in _hazardousKeywords) {
        if (_containsWordOrPhrase(lower, kw)) {
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
        if (cat == 'fire_safety' &&
            (kw == 'cháy' || kw == 'chay') &&
            isLampBurnout) {
          continue;
        }

        if (_containsWordOrPhrase(lower, kw)) {
          final weight = kw.contains(' ') ? 2 : 1;
          scores[cat] = (scores[cat] ?? 0) + weight;
          matchedWords[cat]!.add(kw);
        }
      }
    });

    // Sắp xếp danh mục theo điểm số
    final sortedCats = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final bestEntry = sortedCats.first;

    String selectedCategory = 'other';
    double confidence = 0.3;
    String reason =
        'Không tìm thấy từ khóa chuyên môn phù hợp, xếp vào mục Khác.';

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
    final hotlines = <String>['02439998888'];
    if (isHazardous) {
      if (isFireHazard) {
        hazardAlert =
            'Tình huống có thể gây nguy hiểm cháy nổ! Vui lòng gọi ngay Cứu hỏa 114 hoặc Hotline Ban Quản Lý và giữ khoảng cách an toàn.';
        hotlines.insert(0, '114');
      } else if (hasElevatorStuck || hasTrappedPerson) {
        hazardAlert =
            'Sự cố kẹt thang máy / mắc kẹt người! Vui lòng gọi Cứu nạn 114 hoặc Cấp cứu 115 và Hotline BQL.';
        hotlines.insert(0, '114');
        hotlines.insert(1, '115');
      } else {
        hazardAlert =
            'Tình huống có thể gây nguy hiểm! Vui lòng gọi ngay Hotline Ban Quản Lý và giữ khoảng cách an toàn.';
      }
    }

    return IssueTriageResult(
      category: selectedCategory,
      priority: priority,
      confidence: confidence,
      isHazardous: isHazardous,
      isFireHazard: isFireHazard,
      isTrappedPersonHazard: hasElevatorStuck || hasTrappedPerson,
      reason: reason,
      suggestedStaffRole: suggestedStaffRole,
      hazardAlertMessage: hazardAlert,
      emergencyHotlines: hotlines,
    );
  }
}
