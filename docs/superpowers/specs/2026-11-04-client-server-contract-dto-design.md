# Đặc Tả Thiết Kế: Hợp Đồng Client ↔ Server Chặt Chẽ (Strongly-Typed RPC DTOs & Contract Tests)

## 1. Tổng Quan & Mục Tiêu

Trong hệ thống SaaS Quản lý Tòa nhà Thương Mại (PKA-Home), tầng ứng dụng Flutter tương tác với PostgreSQL Backend chủ yếu thông qua các Remote Procedure Calls (RPC). 

Trước đây, các repository truyền tham số dạng `Map<String, dynamic>` tự do và bóc tách kết quả bằng các khóa chuỗi (`res['success']`, `res['message']`). Điều này tiềm ẩn các rủi ro:
1. **Lỗi chính tả tham số:** Nếu lập trình viên gõ nhầm tên tham số `p_*` (ví dụ `p_buildingId` thay vì `p_building_id`), lỗi chỉ phát sinh ở runtime trên máy người dùng.
2. **Thiếu ràng buộc kiểu:** Không thể kiểm tra kiểu dữ liệu (kiểu số nguyên, chuỗi, boolean, enum) ở thời điểm biên dịch (Compile-time type safety).
3. **Mất an toàn khi refactor backend:** Khi một migration SQL thay đổi schema kết quả trả về, client không có cơ chế phát hiện tự động.

**Mục tiêu của giải pháp:**
- Xây dựng hệ thống Strongly-Typed DTOs chuẩn hóa cho toàn bộ các RPC nghiệp vụ quan trọng.
- Cung cấp `RpcContractClient` tiện ích gọi RPC an toàn, tự động bọc lỗi và parse phản hồi có kiểu tường minh.
- Viết bộ Contract Tests kiểm thử tự động tính toàn vẹn 2 chiều giữa tham số đầu vào của client và định nghĩa tham số PostgreSQL `p_*` trong migrations.
- Nâng cấp các Repositories cốt lõi sử dụng DTO thay cho map thô.

---

## 2. Kiến Trúc & Cấu Trúc Thư Mục

```text
lib/
├── data/
│   ├── contracts/
│   │   ├── rpc_contract_client.dart            # Wrapper gọi Supabase RPC type-safe
│   │   ├── finance_rpc_contracts.dart          # DTOs cho Quỹ bảo trì, Webhook, Onboarding, Đôn đốc nợ
│   │   ├── booking_rpc_contracts.dart          # DTOs cho Đặt tiện ích, Hủy lịch fail-closed, Check-in
│   │   ├── operations_rpc_contracts.dart       # DTOs cho AI triage sự cố, Ghi chỉ số, Khách, Bưu kiện
│   │   └── community_rpc_contracts.dart        # DTOs cho Biểu quyết, Kiến nghị
│   └── repositories/                           # Tích hợp DTOs vào các Repositories
test/
└── contracts/
    └── rpc_contracts_test.dart                 # Contract tests kiểm thử schema và serialization
```

---

## 3. Chi Tiết Các Hợp Đồng RPC (Contracts Specification)

### 3.1. Nhóm Tài Chính & Kế Toán (`finance_rpc_contracts.dart`)

1. **`RecordMaintenanceTransaction`**
   - RPC: `record_maintenance_fund_transaction`
   - Request DTO:
     - `p_building_id` (String)
     - `p_transaction_type` (String: `'COLLECTION'` | `'DISBURSEMENT'`)
     - `p_amount` (double)
     - `p_counterparty_name` (String)
     - `p_description` (String)
     - `p_bank_reference` (String?)
     - `p_apartment_id` (String?)
     - `p_category` (String?)
   - Response DTO:
     - `success` (bool)
     - `transactionId` (String?)
     - `voucherNumber` (String?)
     - `message` (String)

2. **`ProcessBankPaymentWebhook`**
   - RPC: `process_bank_payment_webhook`
   - Request DTO:
     - `p_gateway_name` (String)
     - `p_transaction_id` (String)
     - `p_amount` (double)
     - `p_virtual_account` (String?)
     - `p_transfer_content` (String)
     - `p_signature` (String)
     - `p_raw_payload` (Map<String, dynamic>?)
   - Response DTO:
     - `success` (bool)
     - `status` (String)
     - `invoiceId` (String?)
     - `message` (String)

3. **`PredictDebtRisk` & `ExecuteDunningAction`**
   - Request/Response tương ứng các tham số của module rủi ro nợ xấu và đôn đốc đa tầng.

### 3.2. Nhóm Tiện Ích & Đặt Chỗ (`booking_rpc_contracts.dart`)

1. **`BookAmenitySlot`**
   - RPC: `book_amenity_slot`
   - Request DTO:
     - `p_building_id` (String)
     - `p_amenity_id` (String)
     - `p_user_id` (String)
     - `p_apartment_id` (String)
     - `p_booking_date` (String: `YYYY-MM-DD`)
     - `p_slot_time` (String)
     - `p_total_price` (double)
     - `p_payment_type` (String)
   - Response DTO:
     - `success` (bool)
     - `bookingId` (String?)
     - `message` (String)

2. **`CancelAmenityBooking`**
   - RPC: `cancel_amenity_booking`
   - Request DTO:
     - `p_booking_id` (String)
     - `p_user_id` (String)
     - `p_reason` (String)
   - Response DTO:
     - `success` (bool)
     - `refundStatus` (String?)
     - `message` (String)

### 3.3. Nhóm Vận Hành & Khách Ra Vào (`operations_rpc_contracts.dart`)

1. **`TriageIssueReport`**
   - RPC: `triage_and_auto_assign_issue`
   - Request DTO: `p_issue_id` (String), `p_description` (String), `p_category` (String?)
   - Response DTO: `success` (bool), `priority` (String), `assignedStaffId` (String?), `confidence` (double)

2. **`VisitorPassCheckIn` / `CollectParcel`**
   - Chuẩn hóa request `p_pass_id`, `p_guard_id` và response trạng thái.

---

## 4. `RpcContractClient` Type-Safe Wrapper

```dart
class RpcContractClient {
  final SupabaseClient client;

  RpcContractClient(this.client);

  Future<TResponse> execute<TRequest, TResponse>({
    required String rpcName,
    required TRequest request,
    required Map<String, dynamic> Function(TRequest) toParams,
    required TResponse Function(dynamic) fromResponse,
  }) async {
    try {
      final params = toParams(request);
      final rawResponse = await client.rpc(rpcName, params: params);
      return fromResponse(rawResponse);
    } catch (e, stack) {
      // Chuẩn hóa và đóng gói ngoại lệ có ngữ cảnh tiếng Việt
      throw RpcContractException(
        rpcName: rpcName,
        message: 'Lỗi khi gọi RPC $rpcName: $e',
        underlyingError: e,
        stackTrace: stack,
      );
    }
  }
}
```

---

## 5. Kế Hoạch Kiểm Thử (Testing Plan)

- **Unit & Contract Tests:**
  - `test/contracts/rpc_contracts_test.dart`:
    - Kiểm thử Serialization: Mọi Request DTO sinh ra `Map<String, dynamic>` có đúng 100% tên tham số có tiền tố `p_*` như định nghĩa trong các migration SQL.
    - Kiểm thử Deserialization: Parse các mẫu JSON phản hồi thành công (`success: true`) và thất bại (`success: false`, `error: ...`) trả về đúng object strongly-typed.
    - Kiểm thử Edge Cases: Giá trị null, chuỗi rỗng, số thực thập phân, định dạng ngày tháng `YYYY-MM-DD`.
  - Kiểm thử `RpcContractClient`: Mô phỏng gọi thành công và lỗi mạng/lỗi database để xác thực cơ chế đóng gói `RpcContractException`.

---

## 6. Tiêu Chí Hoàn Thành (Definition of Done)

- [ ] Toàn bộ 4 file DTO Contracts được tạo trong `lib/data/contracts/`.
- [ ] `RpcContractClient` được triển khai với xử lý lỗi chuẩn mực tiếng Việt.
- [ ] Các Repositories trọng yếu (`MaintenanceFundRepository`, `AmenityBookingRepository`, `DebtPredictionRepository`) được cập nhật sử dụng DTO Contracts.
- [ ] Bộ Contract Tests tự động đạt 100% PASS.
- [ ] `dart analyze lib test` đạt 0 issues (No issues found!).
- [ ] Cập nhật Roadmap `COMMERCIAL_PRODUCT_ROADMAP.md` và đồ thị `graphify`.
- [ ] Commit trực tiếp trên `main` và push lên GitHub remote.
