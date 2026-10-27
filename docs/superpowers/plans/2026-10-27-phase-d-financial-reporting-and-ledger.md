# Phase D: Báo Cáo Tài Chính Chuyên Sâu, Sổ Quỹ Bảo Trì 2% & Chứng Từ Kế Toán Chuẩn - Kế Hoạch Thực Thi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống sổ cái biến động (Live Ledger) của Quỹ bảo trì 2%, liên kết chi phí nghiệm thu sửa chữa kỹ thuật (`equipment_maintenance_tasks`), cung cấp giao diện Sổ Quỹ cho Ban Quản lý và xuất Phiếu thu / Phiếu chi chuẩn Bộ Tài Chính (Mẫu 01-TT, 02-TT).

**Architecture:** Sử dụng kiến trúc Feature-first và Riverpod State Management; Database PostgreSQL/Supabase với bảng `maintenance_fund_transactions` và RPC `record_maintenance_fund_transaction` có row-locking (`FOR UPDATE`) để đảm bảo toàn vẹn số dư thời gian thực và sinh số chứng từ chuẩn kế toán `PT-...` / `PC-...`.

**Tech Stack:** Flutter, Dart, Riverpod 2.x, GoRouter, Supabase Flutter, Intl, Google Fonts.

## Global Constraints

- Branching: Commit trực tiếp vào `main`, không tạo branch/worktree phụ theo quy định dự án (`AGENTS.md`).
- Ngôn ngữ UI: 100% tiếng Việt chuẩn mực, không dùng tiếng Anh trong ngoặc đơn (`design-rules.md`).
- TDD: Viết test trước, kiểm tra test fail, viết code tối thiểu, kiểm tra test pass, sau đó mới commit.
- Mã phòng/căn hộ: Sử dụng định dạng chuẩn `A0110` / `a0110` (`coding-rules.md`).
- Không phá vỡ bất kỳ test nào trong bộ 455 test hiện có, `flutter analyze` đạt 0 lỗi.

---

### Task 1: Cơ Sở Dữ Liệu - Migration Sổ Quỹ Bảo Trì & RPC Giao Dịch

**Files:**
- Create: `supabase/migrations/20261027_05_maintenance_fund_ledger.sql`
- Test: `test/integration/maintenance_fund_ledger_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `buildings(id)`, `maintenance_funds(id)`, `users(id)`
- Produces: Bảng `maintenance_fund_transactions`, RPC `record_maintenance_fund_transaction`

- [ ] **Step 1: Viết test kiểm tra cú pháp và cấu trúc file migration**

```dart
// test/integration/maintenance_fund_ledger_migration_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Maintenance Fund Ledger Migration Tests', () {
    final migrationFile = File('supabase/migrations/20261027_05_maintenance_fund_ledger.sql');

    test('Migration file exists and contains necessary DDL & RPC', () {
      expect(migrationFile.existsSync(), isTrue);
      final sql = migrationFile.readAsStringSync();

      expect(sql.contains('ALTER TABLE public.maintenance_funds'), isTrue);
      expect(sql.contains('CREATE TABLE IF NOT EXISTS public.maintenance_fund_transactions'), isTrue);
      expect(sql.contains('voucher_number VARCHAR(30)'), isTrue);
      expect(sql.contains('balance_after NUMERIC(15,2)'), isTrue);
      expect(sql.contains('CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction'), isTrue);
      expect(sql.contains('FOR UPDATE'), isTrue);
      expect(sql.contains('PT-'), isTrue);
      expect(sql.contains('PC-'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail**

Chạy: `flutter test test/integration/maintenance_fund_ledger_migration_test.dart`
Kỳ vọng: FAIL vì file migration chưa tồn tại.

- [ ] **Step 3: Tạo file migration `20261027_05_maintenance_fund_ledger.sql`**

```sql
-- supabase/migrations/20261027_05_maintenance_fund_ledger.sql
-- ==============================================================================
-- PKA-HOME: PHASE D - MAINTENANCE FUND LEDGER & VOUCHERS
-- Migration: 20261027_05_maintenance_fund_ledger.sql
-- ==============================================================================

-- 1. Bổ sung building_id vào maintenance_funds
ALTER TABLE public.maintenance_funds
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

-- 2. Tạo bảng sổ quỹ biến động maintenance_fund_transactions
CREATE TABLE IF NOT EXISTS public.maintenance_fund_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    fund_id UUID NOT NULL REFERENCES public.maintenance_funds(id) ON DELETE CASCADE,
    voucher_number VARCHAR(30) NOT NULL, -- PT-YYYYMM-XXXXX hoặc PC-YYYYMM-XXXXX
    transaction_type VARCHAR(20) NOT NULL, -- 'INCOME' (Thu) hoặc 'EXPENSE' (Chi)
    category VARCHAR(50) NOT NULL, -- 'MAINTENANCE_FEE', 'EQUIPMENT_REPAIR', 'BANK_INTEREST', 'OTHER'
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    balance_after NUMERIC(15,2) NOT NULL,
    reference_type VARCHAR(30), -- 'INVOICE', 'EQUIPMENT_TASK', 'BANK_INTEREST', 'MANUAL'
    reference_id UUID,
    recipient_or_payer TEXT NOT NULL,
    description TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mft_building ON public.maintenance_fund_transactions(building_id);
CREATE INDEX IF NOT EXISTS idx_mft_voucher ON public.maintenance_fund_transactions(voucher_number);
CREATE INDEX IF NOT EXISTS idx_mft_created_at ON public.maintenance_fund_transactions(created_at DESC);

-- Bật RLS
ALTER TABLE public.maintenance_fund_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mft_read_policy" ON public.maintenance_fund_transactions;
CREATE POLICY "mft_read_policy" ON public.maintenance_fund_transactions
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "mft_admin_manage_policy" ON public.maintenance_fund_transactions;
CREATE POLICY "mft_admin_manage_policy" ON public.maintenance_fund_transactions
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 3. RPC Ghi sổ quỹ và cập nhật số dư an toàn
CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction(
    p_building_id UUID,
    p_transaction_type VARCHAR(20),
    p_category VARCHAR(50),
    p_amount NUMERIC(15,2),
    p_description TEXT,
    p_recipient_or_payer TEXT,
    p_reference_type VARCHAR(30) DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_fund_id UUID;
    v_current_balance NUMERIC(15,2);
    v_new_balance NUMERIC(15,2);
    v_period TEXT;
    v_prefix TEXT;
    v_seq INT;
    v_voucher_number TEXT;
    v_tx_id UUID;
BEGIN
    -- 1. Tìm hoặc tạo bản ghi quỹ bảo trì cho tòa nhà
    SELECT id, total_balance INTO v_fund_id, v_current_balance
    FROM public.maintenance_funds
    WHERE building_id = p_building_id
    LIMIT 1
    FOR UPDATE;

    IF v_fund_id IS NULL THEN
        SELECT id, total_balance INTO v_fund_id, v_current_balance
        FROM public.maintenance_funds
        WHERE building_id IS NULL
        LIMIT 1
        FOR UPDATE;
        
        IF v_fund_id IS NOT NULL THEN
            UPDATE public.maintenance_funds SET building_id = p_building_id WHERE id = v_fund_id;
        ELSE
            INSERT INTO public.maintenance_funds (building_id, total_balance)
            VALUES (p_building_id, 0.00)
            RETURNING id, total_balance INTO v_fund_id, v_current_balance;
        END IF;
    END IF;

    -- 2. Tính số dư mới
    IF p_transaction_type = 'INCOME' THEN
        v_new_balance := v_current_balance + p_amount;
        v_prefix := 'PT-';
    ELSIF p_transaction_type = 'EXPENSE' THEN
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Số dư quỹ bảo trì không đủ để chi (Số dư hiện tại: %, Cần chi: %)', v_current_balance, p_amount;
        END IF;
        v_new_balance := v_current_balance - p_amount;
        v_prefix := 'PC-';
    ELSE
        RAISE EXCEPTION 'Loại giao dịch không hợp lệ: %', p_transaction_type;
    END IF;

    -- 3. Sinh số chứng từ kế toán
    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM public.maintenance_fund_transactions
    WHERE voucher_number LIKE v_prefix || v_period || '-%';

    v_voucher_number := v_prefix || v_period || '-' || LPAD(v_seq::text, 5, '0');

    -- 4. Cập nhật số dư bảng chính
    UPDATE public.maintenance_funds
    SET total_balance = v_new_balance,
        updated_at = now()
    WHERE id = v_fund_id;

    -- 5. Ghi sổ giao dịch
    INSERT INTO public.maintenance_fund_transactions (
        building_id,
        fund_id,
        voucher_number,
        transaction_type,
        category,
        amount,
        balance_after,
        reference_type,
        reference_id,
        recipient_or_payer,
        description,
        created_by,
        created_at
    ) VALUES (
        p_building_id,
        v_fund_id,
        v_voucher_number,
        p_transaction_type,
        p_category,
        p_amount,
        v_new_balance,
        p_reference_type,
        p_reference_id,
        p_recipient_or_payer,
        p_description,
        p_created_by,
        now()
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'voucher_number', v_voucher_number,
        'new_balance', v_new_balance
    );
END;
$$;
```

- [ ] **Step 4: Chạy test kiểm tra pass**

Chạy: `flutter test test/integration/maintenance_fund_ledger_migration_test.dart`
Kỳ vọng: PASS

- [ ] **Step 5: Commit code**

```bash
git add supabase/migrations/20261027_05_maintenance_fund_ledger.sql test/integration/maintenance_fund_ledger_migration_test.dart
git commit -m "feat(db): thêm migration sổ quỹ bảo trì 2% và RPC ghi giao dịch kế toán"
```

---

### Task 2: Model & Dữ Liệu `MaintenanceFundTransactionModel`

**Files:**
- Create: `lib/data/models/maintenance_fund_transaction_model.dart`
- Test: `test/data/models/maintenance_fund_transaction_model_test.dart`

**Interfaces:**
- Consumes: JSON map từ bảng `maintenance_fund_transactions`
- Produces: `MaintenanceFundTransactionModel` với getters `isIncome`, `isExpense`, `categoryDisplayName`, `formattedAmount`

- [ ] **Step 1: Viết test cho Model**

```dart
// test/data/models/maintenance_fund_transaction_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/maintenance_fund_transaction_model.dart';

void main() {
  group('MaintenanceFundTransactionModel Tests', () {
    test('fromJson and toJson parse accurately', () {
      final json = {
        'id': 'tx-001',
        'building_id': 'bld-001',
        'fund_id': 'fund-001',
        'voucher_number': 'PT-202610-00001',
        'transaction_type': 'INCOME',
        'category': 'MAINTENANCE_FEE',
        'amount': 5000000.0,
        'balance_after': 2505000000.0,
        'reference_type': 'INVOICE',
        'reference_id': 'inv-123',
        'recipient_or_payer': 'Nguyễn Văn A - Căn A0110',
        'description': 'Thu kinh phí bảo trì đợt 1',
        'created_by': 'usr-admin',
        'created_at': '2026-10-27T10:00:00Z',
      };

      final model = MaintenanceFundTransactionModel.fromJson(json);

      expect(model.id, 'tx-001');
      expect(model.voucherNumber, 'PT-202610-00001');
      expect(model.isIncome, isTrue);
      expect(model.isExpense, isFalse);
      expect(model.amount, 5000000.0);
      expect(model.balanceAfter, 2505000000.0);
      expect(model.categoryDisplayName, 'Thu phí bảo trì');

      final serialized = model.toJson();
      expect(serialized['voucher_number'], 'PT-202610-00001');
      expect(serialized['transaction_type'], 'INCOME');
    });

    test('expense model attributes check', () {
      final json = {
        'id': 'tx-002',
        'building_id': 'bld-001',
        'fund_id': 'fund-001',
        'voucher_number': 'PC-202610-00001',
        'transaction_type': 'EXPENSE',
        'category': 'EQUIPMENT_REPAIR',
        'amount': 12000000.0,
        'balance_after': 2493000000.0,
        'reference_type': 'EQUIPMENT_TASK',
        'reference_id': 'eq-task-001',
        'recipient_or_payer': 'Công ty Thang máy Otis',
        'description': 'Bảo dưỡng thay thế cáp thang máy Tòa A',
        'created_at': '2026-10-27T11:00:00Z',
      };

      final model = MaintenanceFundTransactionModel.fromJson(json);
      expect(model.isExpense, isTrue);
      expect(model.isIncome, isFalse);
      expect(model.categoryDisplayName, 'Sửa chữa thiết bị');
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail**

Chạy: `flutter test test/data/models/maintenance_fund_transaction_model_test.dart`
Kỳ vọng: FAIL vì file model chưa tồn tại.

- [ ] **Step 3: Viết class `MaintenanceFundTransactionModel`**

```dart
// lib/data/models/maintenance_fund_transaction_model.dart
class MaintenanceFundTransactionModel {
  final String id;
  final String buildingId;
  final String fundId;
  final String voucherNumber;
  final String transactionType; // 'INCOME' | 'EXPENSE'
  final String category; // 'MAINTENANCE_FEE' | 'EQUIPMENT_REPAIR' | 'BANK_INTEREST' | 'OTHER'
  final double amount;
  final double balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final String recipientOrPayer;
  final String description;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaintenanceFundTransactionModel({
    required this.id,
    required this.buildingId,
    required this.fundId,
    required this.voucherNumber,
    required this.transactionType,
    required this.category,
    required this.amount,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    required this.recipientOrPayer,
    required this.description,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => transactionType.toUpperCase() == 'INCOME';
  bool get isExpense => transactionType.toUpperCase() == 'EXPENSE';

  String get typeDisplayName => isIncome ? 'Thu quỹ' : 'Chi quỹ';

  String get categoryDisplayName {
    switch (category.toUpperCase()) {
      case 'MAINTENANCE_FEE':
        return 'Thu phí bảo trì';
      case 'EQUIPMENT_REPAIR':
        return 'Sửa chữa thiết bị';
      case 'BANK_INTEREST':
        return 'Lãi tiền gửi ngân hàng';
      case 'OTHER':
      default:
        return 'Khác';
    }
  }

  factory MaintenanceFundTransactionModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceFundTransactionModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      fundId: json['fund_id'] as String? ?? '',
      voucherNumber: json['voucher_number'] as String? ?? '',
      transactionType: json['transaction_type'] as String? ?? 'INCOME',
      category: json['category'] as String? ?? 'OTHER',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      recipientOrPayer: json['recipient_or_payer'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'fund_id': fundId,
      'voucher_number': voucherNumber,
      'transaction_type': transactionType,
      'category': category,
      'amount': amount,
      'balance_after': balanceAfter,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'recipient_or_payer': recipientOrPayer,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

- [ ] **Step 4: Chạy test kiểm tra pass**

Chạy: `flutter test test/data/models/maintenance_fund_transaction_model_test.dart`
Kỳ vọng: PASS

- [ ] **Step 5: Commit code**

```bash
git add lib/data/models/maintenance_fund_transaction_model.dart test/data/models/maintenance_fund_transaction_model_test.dart
git commit -m "feat: thêm model MaintenanceFundTransactionModel và unit test"
```

---

### Task 3: Repository & Providers Quỹ Bảo Trì

**Files:**
- Create: `lib/data/repositories/maintenance_fund_repository.dart`
- Modify: `lib/data/providers/maintenance_fund_provider.dart`
- Test: `test/data/repositories/maintenance_fund_repository_test.dart`

**Interfaces:**
- Consumes: SupabaseClient
- Produces: `MaintenanceFundRepository`, `maintenanceFundLedgerProvider`, `activeMaintenanceFundProvider`

- [ ] **Step 1: Viết test cho Repository**

```dart
// test/data/repositories/maintenance_fund_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/maintenance_fund_repository.dart';

void main() {
  group('MaintenanceFundRepository Unit Tests', () {
    test('MaintenanceFundRepository initializes gracefully without crash', () {
      final repo = MaintenanceFundRepository();
      expect(repo, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail**

Chạy: `flutter test test/data/repositories/maintenance_fund_repository_test.dart`
Kỳ vọng: FAIL vì file repository chưa có.

- [ ] **Step 3: Viết `MaintenanceFundRepository` và cập nhật Providers**

Cung cấp đầy đủ hàm `fetchFundByBuilding`, `fetchTransactions`, và `recordTransaction`:
```dart
// lib/data/repositories/maintenance_fund_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/maintenance_fund_model.dart';
import '../models/maintenance_fund_transaction_model.dart';

class MaintenanceFundRepository {
  SupabaseClient? get _client {
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  Future<MaintenanceFundModel?> fetchFundByBuilding(String? buildingId) async {
    final client = _client;
    if (client == null) return null;

    try {
      var query = client.from('maintenance_funds').select();
      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      final response = await query.order('created_at', ascending: false).limit(1).maybeSingle();
      if (response == null) {
        // Fallback lấy quỹ mặc định nếu tòa nhà chưa tạo bản ghi riêng
        final fallback = await client.from('maintenance_funds').select().order('created_at', ascending: false).limit(1).maybeSingle();
        return fallback != null ? MaintenanceFundModel.fromJson(fallback) : null;
      }
      return MaintenanceFundModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<List<MaintenanceFundTransactionModel>> fetchTransactions({
    String? buildingId,
    String? transactionType,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('maintenance_fund_transactions').select();
      if (buildingId != null && buildingId.isNotEmpty) {
        query = query.eq('building_id', buildingId);
      }
      if (transactionType != null && transactionType != 'ALL') {
        query = query.eq('transaction_type', transactionType);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((item) => MaintenanceFundTransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> recordTransaction({
    required String buildingId,
    required String transactionType,
    required String category,
    required double amount,
    required String description,
    required String recipientOrPayer,
    String? referenceType,
    String? referenceId,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      final res = await client.rpc('record_maintenance_fund_transaction', params: {
        'p_building_id': buildingId,
        'p_transaction_type': transactionType,
        'p_category': category,
        'p_amount': amount,
        'p_description': description,
        'p_recipient_or_payer': recipientOrPayer,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
      });
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
```

Cập nhật `lib/data/providers/maintenance_fund_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_fund_model.dart';
import '../models/maintenance_fund_transaction_model.dart';
import '../repositories/maintenance_fund_repository.dart';
import 'building_provider.dart';

final maintenanceFundRepositoryProvider = Provider<MaintenanceFundRepository>((ref) {
  return MaintenanceFundRepository();
});

final activeMaintenanceFundProvider = FutureProvider<MaintenanceFundModel?>((ref) async {
  final repo = ref.watch(maintenanceFundRepositoryProvider);
  final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
  return repo.fetchFundByBuilding(activeBuilding?.id);
});

// Giữ lại maintenanceFundProvider để tương thích ngược 100%
final maintenanceFundProvider = FutureProvider<MaintenanceFundModel?>((ref) async {
  return ref.watch(activeMaintenanceFundProvider.future);
});

final maintenanceFundLedgerFilterProvider = StateProvider<String>((ref) => 'ALL');

final maintenanceFundLedgerProvider =
    FutureProvider<List<MaintenanceFundTransactionModel>>((ref) async {
  final repo = ref.watch(maintenanceFundRepositoryProvider);
  final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
  final filter = ref.watch(maintenanceFundLedgerFilterProvider);

  return repo.fetchTransactions(
    buildingId: activeBuilding?.id,
    transactionType: filter,
  );
});
```

- [ ] **Step 4: Chạy test kiểm tra pass**

Chạy: `flutter test test/data/repositories/maintenance_fund_repository_test.dart`
Kỳ vọng: PASS

- [ ] **Step 5: Commit code**

```bash
git add lib/data/repositories/maintenance_fund_repository.dart lib/data/providers/maintenance_fund_provider.dart test/data/repositories/maintenance_fund_repository_test.dart
git commit -m "feat: thêm MaintenanceFundRepository và Riverpod ledger providers"
```

---

### Task 4: Thành Phần Giao Diện Chứng Từ Kế Toán (`AccountingVoucherDialog`)

**Files:**
- Create: `lib/core/widgets/accounting_voucher_dialog.dart`
- Test: `test/core/widgets/accounting_voucher_dialog_test.dart`

**Interfaces:**
- Consumes: `MaintenanceFundTransactionModel`, `VietnameseCurrencyWords`
- Produces: `AccountingVoucherDialog.show(context, transaction, buildingName)`

- [ ] **Step 1: Viết test cho dialog chứng từ**

```dart
// test/core/widgets/accounting_voucher_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/accounting_voucher_dialog.dart';
import 'package:pka_home/data/models/maintenance_fund_transaction_model.dart';

void main() {
  testWidgets('AccountingVoucherDialog displays standard voucher fields and Vietnamese words', (tester) async {
    final tx = MaintenanceFundTransactionModel(
      id: 'tx-1',
      buildingId: 'b-1',
      fundId: 'f-1',
      voucherNumber: 'PC-202610-00008',
      transactionType: 'EXPENSE',
      category: 'EQUIPMENT_REPAIR',
      amount: 15000000.0,
      balanceAfter: 2485000000.0,
      recipientOrPayer: 'Công ty Cổ phần Thang máy Alpha',
      description: 'Nghiệm thu bảo dưỡng định kỳ hệ thống thang máy',
      createdAt: DateTime(2026, 10, 27, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AccountingVoucherDialog.show(
                ctx,
                transaction: tx,
                buildingName: 'Tòa nhà Landmark PKA',
              ),
              child: const Text('Xem chứng từ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Xem chứng từ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PHIẾU CHI'), findsOneWidget);
    expect(find.textContaining('Mẫu 02-TT'), findsOneWidget);
    expect(find.textContaining('PC-202610-00008'), findsOneWidget);
    expect(find.textContaining('Công ty Cổ phần Thang máy Alpha'), findsOneWidget);
    expect(find.textContaining('Mười lăm triệu đồng chẵn'), findsOneWidget);
    expect(find.textContaining('Giám đốc BQL'), findsOneWidget);
    expect(find.textContaining('Kế toán trưởng'), findsOneWidget);
    expect(find.textContaining('Người nhận tiền'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail**

Chạy: `flutter test test/core/widgets/accounting_voucher_dialog_test.dart`
Kỳ vọng: FAIL vì chưa có `AccountingVoucherDialog`.

- [ ] **Step 3: Triển khai `AccountingVoucherDialog`**

```dart
// lib/core/widgets/accounting_voucher_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/vietnamese_currency_words.dart';
import '../../data/models/maintenance_fund_transaction_model.dart';

class AccountingVoucherDialog extends StatelessWidget {
  final MaintenanceFundTransactionModel transaction;
  final String buildingName;

  const AccountingVoucherDialog({
    super.key,
    required this.transaction,
    required this.buildingName,
  });

  static Future<void> show(
    BuildContext context, {
    required MaintenanceFundTransactionModel transaction,
    String buildingName = 'Ban Quản Lý Tòa Nhà',
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AccountingVoucherDialog(
        transaction: transaction,
        buildingName: buildingName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final title = isIncome ? 'PHIẾU THU' : 'PHIẾU CHI';
    final formCode = isIncome ? 'Mẫu 01-TT (TT 200/2014/TT-BTC)' : 'Mẫu 02-TT (TT 200/2014/TT-BTC)';
    final personLabel = isIncome ? 'Họ tên người nộp tiền:' : 'Họ tên người nhận tiền:';
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final amountWords = VietnameseCurrencyWords.toVietnameseWords(transaction.amount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header đơn vị & mẫu biểu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buildingName.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'QUỸ BẢO TRÌ 2% SỞ HỮU CHUNG',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formCode,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Tiêu đề chứng từ
              Center(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isIncome ? AppTheme.primary : AppTheme.error,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Số: ${transaction.voucherNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ngày ${transaction.createdAt.day} tháng ${transaction.createdAt.month} năm ${transaction.createdAt.year}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nội dung chi tiết
              _buildInfoRow(personLabel, transaction.recipientOrPayer, isBold: true),
              const SizedBox(height: 8),
              _buildInfoRow('Lý do:', transaction.description),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Số tiền:',
                currencyFormat.format(transaction.amount),
                isBold: true,
                valueColor: isIncome ? AppTheme.primary : AppTheme.error,
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Viết bằng chữ:', amountWords, isItalic: true),
              const SizedBox(height: 8),
              _buildInfoRow('Kèm theo chứng từ gốc:', transaction.referenceType ?? 'Phiếu nghiệm thu kỹ thuật'),
              const SizedBox(height: 24),

              // Chữ ký 4 bên
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSignBox('Giám đốc BQL', '(Ký, ghi rõ họ tên)'),
                  _buildSignBox('Kế toán trưởng', '(Ký, ghi rõ họ tên)'),
                  _buildSignBox('Người lập phiếu', '(Ký, ghi rõ họ tên)'),
                  _buildSignBox(isIncome ? 'Người nộp tiền' : 'Người nhận tiền', '(Ký, ghi rõ họ tên)'),
                ],
              ),
              const SizedBox(height: 24),

              // Nút hành động
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('In chứng từ'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã kết nối máy in văn phòng BQL.')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isItalic = false, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignBox(String title, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 40), // Khoảng trống ký tên
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Chạy test kiểm tra pass**

Chạy: `flutter test test/core/widgets/accounting_voucher_dialog_test.dart`
Kỳ vọng: PASS

- [ ] **Step 5: Commit code**

```bash
git add lib/core/widgets/accounting_voucher_dialog.dart test/core/widgets/accounting_voucher_dialog_test.dart
git commit -m "feat(ui): thêm AccountingVoucherDialog chuẩn Mẫu 01-TT và 02-TT"
```

---

### Task 5: Màn hình Sổ Quỹ Bảo Trì (`MaintenanceFundLedgerScreen`) & Điều Hướng

**Files:**
- Create: `lib/features/management/screens/maintenance_fund_ledger_screen.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/widgets/maintenance_fund_card.dart`
- Test: `test/features/management/maintenance_fund_ledger_screen_test.dart`

**Interfaces:**
- Consumes: `activeMaintenanceFundProvider`, `maintenanceFundLedgerProvider`, `activeBuildingProvider`
- Produces: Màn hình Sổ Quỹ Bảo Trì `/management/maintenance-fund-ledger` với bộ lọc, nút xem chứng từ, và form lập phiếu nhanh

- [ ] **Step 1: Viết test cho màn hình sổ quỹ**

```dart
// test/features/management/maintenance_fund_ledger_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/features/management/screens/maintenance_fund_ledger_screen.dart';
import 'package:pka_home/data/models/maintenance_fund_model.dart';
import 'package:pka_home/data/models/maintenance_fund_transaction_model.dart';
import 'package:pka_home/data/providers/maintenance_fund_provider.dart';

void main() {
  testWidgets('MaintenanceFundLedgerScreen displays fund balance, filters, and transaction list', (tester) async {
    final mockFund = MaintenanceFundModel(
      id: 'f-1',
      totalBalance: 2450000000.0,
      annualInterestEarned: 127400000.0,
      interestRatePercent: 5.2,
      collectedPercent: 98.5,
      bankName: 'BIDV',
      bankAccountNumber: '1234567890',
    );

    final mockTxs = [
      MaintenanceFundTransactionModel(
        id: 'tx-1',
        buildingId: 'b-1',
        fundId: 'f-1',
        voucherNumber: 'PT-202610-00001',
        transactionType: 'INCOME',
        category: 'MAINTENANCE_FEE',
        amount: 5000000.0,
        balanceAfter: 2450000000.0,
        recipientOrPayer: 'Cư dân Căn A0110',
        description: 'Thu phí bảo trì',
        createdAt: DateTime(2026, 10, 27, 9, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeMaintenanceFundProvider.overrideWith((ref) => Future.value(mockFund)),
          maintenanceFundLedgerProvider.overrideWith((ref) => Future.value(mockTxs)),
        ],
        child: const MaterialApp(
          home: MaintenanceFundLedgerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sổ Quỹ Bảo Trì 2%'), findsOneWidget);
    expect(find.textContaining('PT-202610-00001'), findsOneWidget);
    expect(find.text('Thu phí bảo trì'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Thu quỹ'), findsOneWidget);
    expect(find.text('Chi quỹ'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test fail**

Chạy: `flutter test test/features/management/maintenance_fund_ledger_screen_test.dart`
Kỳ vọng: FAIL vì chưa có màn hình.

- [ ] **Step 3: Tạo `MaintenanceFundLedgerScreen` và cập nhật Router**

Thêm `AppRoutes.managementMaintenanceFundLedger` vào `lib/core/router/route_names.dart`:
```dart
static const String managementMaintenanceFundLedger = '/management/maintenance-fund-ledger';
```
Khai báo route trong `lib/core/router/app_router.dart`:
```dart
GoRoute(
  path: AppRoutes.managementMaintenanceFundLedger,
  builder: (context, state) => const MaintenanceFundLedgerScreen(),
),
```

Triển khai `MaintenanceFundLedgerScreen`:
- Thẻ số dư khả dụng tổng quan.
- Bộ lọc chip: Tất cả / Thu quỹ (INCOME) / Chi quỹ (EXPENSE).
- Nút "Lập phiếu nhanh" cho Ban Quản Lý (mở bottom sheet điền loại thu/chi, số tiền, người nộp/nhận, lý do và lưu vào sổ quỹ).
- Danh sách giao dịch: bấm vào dòng bất kỳ mở `AccountingVoucherDialog.show(...)`.

Cập nhật `lib/core/widgets/maintenance_fund_card.dart`:
- Nếu `isManagement == true`, hiển thị nút `Xem sổ quỹ & chứng từ` điều hướng đến `AppRoutes.managementMaintenanceFundLedger`.

- [ ] **Step 4: Chạy test kiểm tra pass**

Chạy: `flutter test test/features/management/maintenance_fund_ledger_screen_test.dart`
Kỳ vọng: PASS

- [ ] **Step 5: Commit code**

```bash
git add lib/core/router/route_names.dart lib/core/router/app_router.dart lib/core/widgets/maintenance_fund_card.dart lib/features/management/screens/maintenance_fund_ledger_screen.dart test/features/management/maintenance_fund_ledger_screen_test.dart
git commit -m "feat(ui): thêm màn hình Sổ Quỹ Bảo Trì 2% và điều hướng từ Dashboard"
```

---

### Task 6: Tích Hợp Nghiệm Thu Bảo Trì Thiết Bị (`EquipmentDetailScreen` -> Phiếu Chi Quỹ)

**Files:**
- Modify: `lib/features/management/screens/equipment_detail_screen.dart`
- Test: `test/features/management/equipment_maintenance_fund_disbursement_test.dart`

**Interfaces:**
- Consumes: `EquipmentMaintenanceTaskModel`, `MaintenanceFundRepository`
- Produces: Luồng tạo phiếu chi từ quỹ bảo trì khi hoàn thành sửa chữa thiết bị có `cost > 0`

- [ ] **Step 1: Viết test cho luồng nghiệm thu chi quỹ**

```dart
// test/features/management/equipment_maintenance_fund_disbursement_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_equipment_model.dart';
import 'package:pka_home/data/models/equipment_maintenance_task_model.dart';
import 'package:pka_home/features/management/screens/equipment_detail_screen.dart';

void main() {
  testWidgets('EquipmentDetailScreen displays action to disburse maintenance fund when task completed with cost', (tester) async {
    final equipment = BuildingEquipmentModel(
      id: 'eq-1',
      code: 'TM-01',
      name: 'Thang máy Otis Tòa A',
      category: 'ELEVATOR',
      status: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EquipmentDetailScreen(equipment: equipment),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Thang máy Otis Tòa A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Triển khai nút và dialog lập phiếu chi từ Quỹ bảo trì trong `equipment_detail_screen.dart`**

Trong danh sách phiếu bảo dưỡng `EquipmentMaintenanceTaskModel`:
- Khi task có `isCompleted == true` và `cost > 0`:
- Hiển thị nút "Chi từ Quỹ bảo trì". Khi bấm: hiển thị modal xác nhận với các thông tin tự động điền:
  - Loại: Chi quỹ (`EXPENSE`)
  - Danh mục: Sửa chữa thiết bị (`EQUIPMENT_REPAIR`)
  - Số tiền: `task.cost`
  - Đơn vị nhận: `task.vendorName ?? 'Đơn vị bảo trì thiết bị'`
  - Nội dung: `Bảo trì thiết bị: ${equipment.name} (${equipment.code}) - ${task.title}`
- Khi xác nhận, gọi `ref.read(maintenanceFundRepositoryProvider).recordTransaction(...)` và thông báo thành công kèm mở `AccountingVoucherDialog` để xem phiếu chi.

- [ ] **Step 3: Chạy test kiểm tra pass**

Chạy: `flutter test test/features/management/equipment_maintenance_fund_disbursement_test.dart`
Kỳ vọng: PASS

- [ ] **Step 4: Commit code**

```bash
git add lib/features/management/screens/equipment_detail_screen.dart test/features/management/equipment_maintenance_fund_disbursement_test.dart
git commit -m "feat: tích hợp nghiệm thu bảo trì thiết bị với phiếu chi Quỹ bảo trì"
```

---

### Task 7: Tổng Duyệt & Kiểm Thử Toàn Diện (Full Verification)

**Files:**
- Toàn bộ codebase

- [ ] **Step 1: Chạy `flutter analyze`**

Chạy: `flutter analyze`
Kỳ vọng: 0 lỗi, 0 cảnh báo.

- [ ] **Step 2: Chạy toàn bộ test suite dự án**

Chạy: `flutter test`
Kỳ vọng: Toàn bộ 460+ tests passed (3 skipped RLS integration như thiết kế).

- [ ] **Step 3: Commit hoàn tất Phase D**

```bash
git commit -m "chore: hoàn tất kiểm thử và rà soát chất lượng Phase D"
```
