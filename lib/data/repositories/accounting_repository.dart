import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/accounting_period_model.dart';
import '../models/apartment_ledger_entry_model.dart';
import '../models/credit_note_model.dart';
import '../models/financial_aging_report_model.dart';

class AccountingRepository {
  final SupabaseClient? _injectedClient;

  AccountingRepository({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  List<ApartmentLedgerEntryModel> parseLedgerEntries(List<dynamic> list) {
    return list
        .map((item) => ApartmentLedgerEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<CreditNoteModel> parseCreditNotes(List<dynamic> list) {
    return list
        .map((item) => CreditNoteModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<AccountingPeriodModel> parseAccountingPeriods(List<dynamic> list) {
    return list
        .map((item) => AccountingPeriodModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApartmentLedgerEntryModel>> fetchLedgerEntries({
    required String apartmentId,
    String? period,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('apartment_ledger_entries').select();
      query = query.eq('apartment_id', apartmentId);
      if (period != null && period.isNotEmpty) {
        query = query.eq('period', period);
      }

      final response = await query.order('created_at', ascending: false);
      return parseLedgerEntries(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<double> fetchApartmentBalance(String apartmentId) async {
    final client = _client;
    if (client == null) return 0.0;

    try {
      final response = await client.rpc(
        'get_apartment_ledger_balance',
        params: {'p_apartment_id': apartmentId},
      );
      if (response != null && response is num) {
        return response.toDouble();
      }
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<CreditNoteModel>> fetchCreditNotes({
    required String buildingId,
    String? apartmentId,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('credit_notes').select();
      if (buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      if (apartmentId != null && apartmentId.isNotEmpty) {
        query = query.eq('apartment_id', apartmentId);
      }

      final response = await query.order('created_at', ascending: false);
      return parseCreditNotes(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<List<AccountingPeriodModel>> fetchAccountingPeriods(String buildingId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('accounting_periods')
          .select()
          .eq('building_id', buildingId)
          .order('period', ascending: false);

      return parseAccountingPeriods(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> recordLedgerEntry({
    required String buildingId,
    required String apartmentId,
    required String entryType,
    required double amount,
    required String period,
    required String referenceType,
    String? referenceId,
    String description = '',
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final params = <String, dynamic>{
        'p_building_id': buildingId,
        'p_apartment_id': apartmentId,
        'p_entry_type': entryType,
        'p_amount': amount,
        'p_period': period,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
        'p_description': description,
        'p_created_by': client.auth.currentUser?.id,
      };

      final response = await client.rpc(
        'record_apartment_ledger_entry',
        params: params,
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> issueCreditNote({
    required String buildingId,
    required String apartmentId,
    String? invoiceId,
    String noteType = 'CREDIT',
    required double amount,
    required String reason,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final params = <String, dynamic>{
        'p_building_id': buildingId,
        'p_apartment_id': apartmentId,
        'p_invoice_id': invoiceId,
        'p_note_type': noteType,
        'p_amount': amount,
        'p_reason': reason,
        'p_approved_by': client.auth.currentUser?.id,
      };

      final response = await client.rpc(
        'issue_credit_note',
        params: params,
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> closeAccountingPeriod({
    required String buildingId,
    required String period,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final params = <String, dynamic>{
        'p_building_id': buildingId,
        'p_period': period,
        'p_closed_by': client.auth.currentUser?.id,
        'p_notes': notes,
      };

      final response = await client.rpc(
        'close_accounting_period',
        params: params,
      );
      return response is Map<String, dynamic> ? response : null;
    } catch (_) {
      return null;
    }
  }

  /// Gọi RPC get_financial_aging_report hoặc fallback tính toán cục bộ
  Future<FinancialAgingReportModel> fetchAgingReport({
    String? buildingId,
    String? period,
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final params = <String, dynamic>{
          'p_building_id': buildingId,
          'p_period': period,
        };
        final response = await client.rpc('get_financial_aging_report', params: params);
        if (response != null && response is Map<String, dynamic>) {
          return FinancialAgingReportModel.fromJson(response);
        }
      } catch (_) {
        // Tiếp tục fallback bên dưới nếu RPC gặp lỗi hoặc mất mạng
      }
    }

    // Fallback: Lấy hóa đơn từ client query hoặc trả về báo cáo tính toán cục bộ
    try {
      if (client != null) {
        var query = client.from('invoices').select('*, apartments(code, building_id)');
        if (period != null && period.isNotEmpty) {
          query = query.eq('period', period);
        }
        final list = await query;
        if (list is List) {
          return calculateAgingReportFallback(
            invoices: list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            filterBuildingId: buildingId,
            filterPeriod: period,
          );
        }
      }
    } catch (_) {}

    return calculateAgingReportFallback(
      invoices: [],
      filterBuildingId: buildingId,
      filterPeriod: period,
    );
  }

  /// Thuật toán tính toán Báo Cáo Tuổi Nợ và Dòng Tiền Offline Fallback
  FinancialAgingReportModel calculateAgingReportFallback({
    required List<Map<String, dynamic>> invoices,
    String? filterBuildingId,
    String? filterPeriod,
  }) {
    final now = DateTime.now();

    var filtered = invoices.where((inv) {
      if (inv['status'] == 'cancelled') return false;
      if (filterPeriod != null && filterPeriod.isNotEmpty) {
        if (inv['period']?.toString() != filterPeriod) return false;
      }
      return true;
    }).toList();

    double totalBilled = 0.0;
    double actualCollected = 0.0;
    double totalOutstanding = 0.0;
    int paidCount = 0;
    int unpaidCount = 0;

    double amount0To30 = 0.0;
    int count0To30 = 0;
    double amount31To60 = 0.0;
    int count31To60 = 0;
    double amount61To90 = 0.0;
    int count61To90 = 0;
    double amountOver90 = 0.0;
    int countOver90 = 0;

    final debtorMap = <String, Map<String, dynamic>>{};
    final blockMap = <String, Map<String, double>>{};

    for (final inv in filtered) {
      final amount = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      final status = inv['status']?.toString() ?? 'unpaid';
      final aptId = inv['apartment_id']?.toString() ?? '';
      
      String aptCode = inv['apartment_code']?.toString() ?? '';
      if (aptCode.isEmpty && inv['apartments'] is Map) {
        aptCode = (inv['apartments'] as Map)['code']?.toString() ?? '';
      }
      if (aptCode.isEmpty) aptCode = 'Căn hộ';

      // Parse block name (ký tự chữ cái đầu)
      final blockMatch = RegExp(r'^[A-Za-z]+').firstMatch(aptCode);
      final blockName = blockMatch?.group(0)?.toUpperCase() ?? 'Chung';

      blockMap.putIfAbsent(blockName, () => {'billed': 0.0, 'collected': 0.0, 'outstanding': 0.0});
      blockMap[blockName]!['billed'] = blockMap[blockName]!['billed']! + amount;

      totalBilled += amount;

      if (status == 'paid') {
        actualCollected += amount;
        paidCount++;
        blockMap[blockName]!['collected'] = blockMap[blockName]!['collected']! + amount;
      } else if (status == 'unpaid' || status == 'overdue') {
        totalOutstanding += amount;
        unpaidCount++;
        blockMap[blockName]!['outstanding'] = blockMap[blockName]!['outstanding']! + amount;

        // Tính số ngày quá hạn
        DateTime? dueDate;
        if (inv['due_date'] != null) {
          dueDate = DateTime.tryParse(inv['due_date'].toString());
        }
        final daysOverdue = dueDate != null ? now.difference(dueDate).inDays : 0;
        final safeOverdue = daysOverdue > 0 ? daysOverdue : 0;

        if (safeOverdue <= 30) {
          amount0To30 += amount;
          count0To30++;
        } else if (safeOverdue <= 60) {
          amount31To60 += amount;
          count31To60++;
        } else if (safeOverdue <= 90) {
          amount61To90 += amount;
          count61To90++;
        } else {
          amountOver90 += amount;
          countOver90++;
        }

        // Cập nhật con nợ
        if (!debtorMap.containsKey(aptId)) {
          debtorMap[aptId] = {
            'apartment_id': aptId,
            'apartment_code': aptCode,
            'owner_name': inv['owner_name']?.toString() ?? 'Cư dân',
            'owner_phone': inv['owner_phone']?.toString() ?? '',
            'total_debt': 0.0,
            'max_days_overdue': safeOverdue,
            'unpaid_invoices_count': 0,
            'oldest_due_date': dueDate?.toIso8601String(),
          };
        }

        final d = debtorMap[aptId]!;
        d['total_debt'] = (d['total_debt'] as double) + amount;
        d['unpaid_invoices_count'] = (d['unpaid_invoices_count'] as int) + 1;
        if (safeOverdue > (d['max_days_overdue'] as int)) {
          d['max_days_overdue'] = safeOverdue;
        }
      }
    }

    final collectionRate = totalBilled > 0 ? (actualCollected / totalBilled) * 100 : 0.0;

    final summary = FinancialAgingSummaryModel(
      totalBilled: totalBilled,
      actualCollected: actualCollected,
      totalOutstanding: totalOutstanding,
      totalInvoiceCount: filtered.length,
      paidInvoiceCount: paidCount,
      unpaidInvoiceCount: unpaidCount,
      collectionRate: double.parse(collectionRate.toStringAsFixed(2)),
    );

    final buckets = DebtAgingBucketModel(
      amount0To30: amount0To30,
      count0To30: count0To30,
      amount31To60: amount31To60,
      count31To60: count31To60,
      amount61To90: amount61To90,
      count61To90: count61To90,
      amountOver90: amountOver90,
      countOver90: countOver90,
    );

    final blockList = blockMap.entries.map((entry) {
      final b = entry.value;
      final rate = b['billed']! > 0 ? (b['collected']! / b['billed']!) * 100 : 0.0;
      return BlockCollectionRateModel(
        blockName: entry.key,
        blockBilled: b['billed']!,
        blockCollected: b['collected']!,
        blockOutstanding: b['outstanding']!,
        collectionRate: double.parse(rate.toStringAsFixed(2)),
      );
    }).toList();
    blockList.sort((a, b) => a.blockName.compareTo(b.blockName));

    final debtorList = debtorMap.values.map((map) {
      final overdue = map['max_days_overdue'] as int;
      String risk = '0_30';
      if (overdue > 90) {
        risk = 'over_90';
      } else if (overdue >= 61) {
        risk = '61_90';
      } else if (overdue >= 31) {
        risk = '31_60';
      }
      map['risk_level'] = risk;
      return DebtorApartmentModel.fromJson(map);
    }).toList();

    debtorList.sort((a, b) {
      final debtCompare = b.totalDebt.compareTo(a.totalDebt);
      if (debtCompare != 0) return debtCompare;
      return b.maxDaysOverdue.compareTo(a.maxDaysOverdue);
    });

    return FinancialAgingReportModel(
      generatedAt: now,
      filterBuildingId: filterBuildingId,
      filterPeriod: filterPeriod,
      summary: summary,
      agingBuckets: buckets,
      collectionByBlock: blockList,
      debtors: debtorList,
    );
  }
}
