---
trigger: always_on
---

# Quy Tắc Coding & Cấu Trúc Dự Án (Flutter)

## 1. Cấu trúc thư mục (Feature-first)
```text
lib/
├── core/                      # Dùng chung toàn app
│   ├── constants/             # Màu sắc, kích thước, chuỗi hằng
│   ├── theme/                 # ThemeData, font Segoe UI/Google Fonts
│   ├── widgets/               # Widget dùng chung (button, card, loading...)
│   └── utils/                 # Hàm tiện ích, formatters
├── data/
│   ├── models/                # Data class ánh xạ bảng CSDL
│   ├── repositories/          # Gọi Supabase, xử lý logic dữ liệu
│   └── providers/             # Riverpod providers
├── features/
│   ├── auth/                  # Đăng nhập, phân quyền
│   ├── resident/              # Toàn bộ màn hình cư dân
│   │   ├── screens/           # Các màn hình (home, invoice, profile...)
│   │   └── widgets/           # Component con của màn hình
│   └── management/            # Toàn bộ màn hình ban quản lý
│       ├── screens/           # Các màn hình (dashboard, resident, issue...)
│       └── widgets/           # Component con của màn hình
└── main.dart
```
> **Lý do**: Tách theo tính năng thay vì theo layer giúp dễ tìm code khi 2 vai trò có luồng UI khác hẳn nhau.

## 2. Quy tắc đặt tên
- **Tên file**: `snake_case` (VD: `resident_home_screen.dart`)
- **Class**: `UpperCamelCase` (VD: `ResidentHomeScreen`)
- **Biến, hàm**: `lowerCamelCase` (VD: `fetchInvoiceList()`)
- **Hằng số**: `lowerCamelCase` + tiền tố `k` (tùy chọn) (VD: `kPrimaryColor`)
- **Riverpod Provider**: tên + hậu tố loại (VD: `invoiceListProvider`, `authStateProvider`)
- **Route/màn hình**: đặt theo path (VD: `/resident/home`)
- **Mã phòng/căn hộ**: Sử dụng định dạng chuẩn `A0110` / `a0110` (Block + Tầng 2 chữ số + Phòng 2 chữ số) trong placeholder, validate và mock data thay vì dạng `A101`.

## 3. Git workflow
- **Branch**: `feature/<ten-tinh-nang>`, `fix/<ten-loi>`, `docs/<ten-tai-lieu>`
- **Commit message**: dạng `<loại>: <mô tả ngắn>` (loại gồm feat, fix, docs, refactor, style, test). VD: `feat: thêm màn hình xem chi tiết hóa đơn`
- **Không commit trực tiếp vào main**: Dùng Pull Request kể cả khi làm một mình để lưu lịch sử review phục vụ báo cáo đồ án.

## 4. Quy tắc quản lý trạng thái (Riverpod)
- Mỗi tính năng có 1 file `*_provider.dart` riêng, không gộp nhiều provider không liên quan.
- Ưu tiên `AsyncNotifierProvider` cho dữ liệu gọi từ Supabase (tự động xử lý loading/error/data).
- Không gọi Supabase trực tiếp trong Widget — luôn gọi qua tầng repository.
