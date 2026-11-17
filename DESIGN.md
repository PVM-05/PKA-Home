---
name: Vivona PropTech Design System
description: Modern Enterprise PropTech SaaS Design System adhering to pbakaus/impeccable standards
colors:
  primary: "#2563EB"
  primary-dark: "#1E40AF"
  secondary: "#0EA5E9"
  neutral-bg: "#F8FAFC"
  surface: "#FFFFFF"
  text-primary: "#0F172A"
  text-secondary: "#64748B"
  border: "#E2E8F0"
  success: "#10B981"
  warning: "#F59E0B"
  error: "#F43F5E"
  paid: "#4CAF50"
  unpaid: "#F44336"
typography:
  display:
    fontFamily: "Segoe UI, Google Fonts, sans-serif"
    fontSize: "2.25rem"
    fontWeight: 700
    lineHeight: 1.2
  headline:
    fontFamily: "Segoe UI, Google Fonts, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.3
  title:
    fontFamily: "Segoe UI, Google Fonts, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 600
    lineHeight: 1.4
  body:
    fontFamily: "Segoe UI, Google Fonts, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Segoe UI, Google Fonts, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.4
rounded:
  sm: "6px"
  md: "10px"
  lg: "12px"
  xl: "16px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: "12px 20px"
---

# Design System

<!-- impeccable:design-schema 1 -->

## Overview

Vivona áp dụng hệ thống thiết kế hiện đại, thanh lịch theo tiêu chuẩn **`pbakaus/impeccable`**, phục vụ nền tảng thương mại B2B SaaS quản lý chung cư & bất động sản. Hệ thống triệt tiêu hoàn toàn hiện tượng "AI slop" (card lồng card, gradient tím xanh, văn bản tràn viền), thiết lập trải nghiệm trực quan, chuẩn xác và tinh tế trên cả Web Enterprise Desktop lẫn Thiết bị di động hiện trường.

## Colors

- **Màu chủ đạo (Primary)**: `#2563EB` (Sapphire Blue) - Biểu tượng của sự chuẩn mực, tin cậy và công nghệ cao.
- **Màu phụ trợ (Secondary)**: `#0EA5E9` (Sky Cyan) - Điểm nhấn cho trạng thái tương tác và dữ liệu động.
- **Màu bề mặt & Nền (Surfaces & Background)**:
  - Nền toàn ứng dụng: `#F8FAFC` (Off-white Slate tinh khiết, dịu mắt).
  - Thẻ & Container nội dung: `#FFFFFF` (Thuần trắng với viền Slate mỏng mờ).
- **Màu chữ (Typography Colors)**:
  - Chữ tiêu đề & chính: `#0F172A` (Slate Navy đậm nét, độ tương phản cao WCAG AAA).
  - Chữ phụ trợ & mô tả: `#64748B` (Neutral Slate nhẹ nhàng, dễ đọc).
- **Màu chỉ báo nghiệp vụ (Semantic Status)**:
  - Đã thanh toán / Tốt / Xác nhận: `#10B981` / `#4CAF50`.
  - Chờ xử lý / Cảnh báo: `#F59E0B`.
  - Chưa thanh toán / Hư hỏng / Lỗi: `#F43F5E` / `#F44336`.

## Typography

- **Phông chữ chủ đạo**: `Segoe UI` (hỗ trợ fallback qua `Google Fonts` Roboto / Inter).
- **Thang tỷ lệ chuẩn (Modular Scale)**:
  - `Display / KPI`: 24px - 32px, Bold 700.
  - `Headline / Screen Title`: 20px - 22px, Bold 700.
  - `Section Title`: 16px - 18px, Semi-Bold 600.
  - `Body / Content`: 14px - 15px, Regular 400 hoặc Medium 500.
  - `Caption / Badge Label`: 11px - 12px, Semi-Bold 600.
- **Quy tắc độ co giãn**: Luôn hỗ trợ `TextScaler` từ 1.0x đến 1.5x mà không bao giờ phá vỡ cấu trúc khối.

## Layout

- **Mạng lưới kích thước (Spacing Grid)**: Dựa trên hệ số cơ sở 4px / 8px (`4, 8, 12, 16, 20, 24, 32px`).
- **Màn hình Di động (< 900dp)**:
  - Căn lề ngoài (Screen Padding): 16px.
  - Bố cục 1 cột cuộn mượt mà qua `SingleChildScrollView` hoặc `ListView`.
  - Khung nội dung giới hạn `maxWidth: 600` căn giữa trên Tablet nhỏ.
- **Màn hình Web Desktop Enterprise ($\ge 900$dp)**:
  - Căn lề ngoài: 24px.
  - Khung bao tổng thể căn giữa `maxWidth: 1400`.
  - Bố cục Workstation 2 cột bất đối xứng (ví dụ: 5 : 7 hoặc 4 : 8) hoặc lưới 2-3 cột (`GridView`).

## Elevation & Depth

- **Triết lý Tonal Layering**: Ưu tiên sử dụng viền mỏng mờ (`Border.all(color: AppTheme.border)` hoặc `alpha: 0.08`) kết hợp màu nền phân tầng thay vì đổ bóng đậm màu.
- **Đổ bóng mờ nhẹ (Soft Shadows)**:
  - `softSm`: `offset(0, 1)`, blur 4px, color `0x0A000000`.
  - `softMd`: `offset(0, 2)`, blur 6px kết hợp `offset(0, 4)`, blur 16px.

## Shapes

- Thẻ chuẩn `AppCard`: Bo góc `12px` (`BorderRadius.circular(12)`).
- Nút bấm chính (Button): Bo góc `10px` (`BorderRadius.circular(10)`).
- Huy hiệu trạng thái (Badge / Chip): Bo góc `6px` - `8px` (`BorderRadius.circular(6)`).
- Khung nhập liệu (Input Field): Bo góc `8px`, viền Slate thanh mảnh.

## Components

- **`AppCard`**: Thành phần thẻ cơ sở bao bọc toàn bộ khối chức năng, tích hợp viền mờ chống tràn, padding mặc định 16px.
- **Executive KPI Card**: Thẻ chỉ số tổng quan với biểu tượng màu bán trong suốt, số liệu in đậm nổi bật và nhãn chú thích co giãn tự động.
- **Status Badge**: Huy hiệu trạng thái với màu nền nhẹ (`color.withValues(alpha: 0.12)`) và chữ đậm cùng tông, luôn bọc `FittedBox` để chống tràn.
- **DropdownButtonFormField**: Thay thế toàn bộ các `DropdownButton` rời rạc bằng `DropdownButtonFormField(isExpanded: true)` để đảm bảo trường nhập chuẩn mực và an toàn tuyệt đối trước văn bản dài.

## Do's and Don'ts

### DO:
- Luôn sử dụng `Expanded` hoặc `Flexible` cho văn bản trong `Row`.
- Luôn sử dụng `Wrap` khi hiển thị danh sách các badge, chip, nút hành động hoặc dữ liệu có thể dài.
- Luôn bọc `LayoutBuilder` cho các khối header/KPI có nguy cơ tràn khi màn hình hẹp dưới 420dp.
- Luôn kiểm thử ở độ phân giải 320dp x 600dp kèm Text Zoom 1.3x.
- Giữ 100% tiếng Việt chuẩn mực SaaS B2B.

### DON'T:
- KHÔNG hardcode chiều cao cố định (`SizedBox(height: 50)`) bao bọc các khối chứa văn bản dài.
- KHÔNG sử dụng emoji trong nhãn, tiêu đề, nút bấm hay thông báo hệ thống.
- KHÔNG dùng từ tiếng Anh trong ngoặc đơn để giải nghĩa (VD: Không dùng `Mật khẩu (Password)`).
- KHÔNG sử dụng màu hardcode rời rạc trong widget (`Colors.blue`, `Color(0xFF1E3A8A)`). Luôn gọi từ `AppTheme`.

