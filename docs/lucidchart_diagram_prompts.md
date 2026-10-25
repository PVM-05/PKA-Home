# BỘ MÃ NGUỒN & PROMPT TẠO SƠ ĐỒ HỆ THỐNG PKA-HOME TRÊN LUCIDCHART
**Dự án: Ứng Dụng Quản Lý Chung Cư (PKA-Home)**  
**Nền tảng mục tiêu: Lucidchart (Hỗ trợ PlantUML, Mermaid, PostgreSQL DDL & Lucidchart AI Prompt)**

---

## MỤC LỤC BỘ SƠ ĐỒ

1. [Hướng Dẫn Nhanh Cách Nhập Vào Lucidchart](#i-hướng-dẫn-cách-nhập-vào-lucidchart)
2. [Sơ Đồ 1: Ngữ Cảnh Hệ Thống (System Context Diagram)](#1-sơ-đồ-ngữ-cảnh-hệ-thống-system-context-diagram)
3. [Sơ Đồ 2: Ca Sử Dụng Tổng Quan & Chi Tiết (Use Case Diagram - 25 Use Cases)](#2-sơ-đồ-ca-sử-dụng-tổng-quan--chi-tiết-use-case-diagram)
4. [Sơ Đồ 3: Quan Hệ Thực Thể CSDL Chi Tiết (ERD - Full 16 Tables)](#3-sơ-đồ-quan-hệ-thực-thể-cơ-sở-dữ-liệu-erd---16-bảng)
5. [Sơ Đồ 4: Sơ Đồ Tuần Tự Nghiệp Vụ Trọng Tâm (Sequence Diagrams)](#4-sơ-đồ-tuần-tự-nghiệp-vụ-trọng-tâm-sequence-diagrams)
   - 4.1. Đặt lịch tiện ích, kiểm soát sức chứa động & tự hủy lịch nguyên tử
   - 4.2. Khai báo chỉ số điện nước, duyệt ảnh & thanh toán mô phỏng 2 bước
6. [Sơ Đồ 5: Sơ Đồ Hoạt Động Nghiệp Vụ (Activity Diagrams có Phân Làn)](#5-sơ-đồ-hoạt-động-nghiệp-vụ-activity-diagrams)
   - 5.1. Hoạt động Đặt tiện ích, sức chứa động & đôn danh sách chờ
   - 5.2. Hoạt động Thẩm định chỉ số & Lập hóa đơn hàng loạt (Preflight)
   - 5.3. Hoạt động Xử lý sự cố, nghiệm thu ảnh & khảo sát 1-5 sao
7. [Sơ Đồ 6: Sơ Đồ Trạng Thái Vòng Đời Thực Thể (State Machine Diagrams)](#6-sơ-đồ-trạng-thái-vòng-đời-thực-thể-state-machine-diagrams)
8. [Sơ Đồ 7: Kiến Trúc Phân Tầng Phần Mềm (Layered Architecture Diagram)](#7-sơ-đồ-kiến-trúc-phân-tầng-phần-mềm-layered-architecture)
9. [Sơ Đồ 8: Triển Khai Hạ Tầng & Dịch Vụ (Deployment Diagram)](#8-sơ-đồ-triển-khai-hạ-tầng-và-dịch-vụ-deployment-diagram)

---

## I. HƯỚNG DẪN CÁCH NHẬP VÀO LUCIDCHART

Bạn có thể đưa các sơ đồ dưới đây vào Lucidchart theo **3 cách linh hoạt nhất**:

### Cách 1: Sử dụng tính năng "Import PlantUML" (Khuyên dùng cho Use Case, Sequence, Activity, Deployment)
1. Mở trang vẽ mới trong **Lucidchart**.
2. Chọn menu **File** $\rightarrow$ **Import Data** $\rightarrow$ Chọn **PlantUML** (hoặc nhấn nút Insert $\rightarrow$ PlantUML).
3. Sao chép (Copy) toàn bộ đoạn mã trong khối `@startuml ... @enduml` tương ứng dán vào ô nhập.
4. Bấm **Insert** $\rightarrow$ Lucidchart sẽ tự động kết xuất ra sơ đồ vector chuẩn UML đẹp mắt, có thể chỉnh sửa màu sắc tùy ý.

### Cách 2: Sử dụng tính năng "Import Mermaid" (Khuyên dùng cho Flowchart, State Machine, Sequence)
1. Mở thanh công cụ bên trái hoặc menu **Insert** $\rightarrow$ Chọn **Mermaid**.
2. Sao chép đoạn mã `mermaid` tương ứng dán vào khung mã.
3. Bấm **Preview** và **Insert Diagram**.

### Cách 3: Sử dụng tính năng "Import SQL DDL" (Dành riêng cho Sơ đồ CSDL / ERD)
1. Trong thanh công cụ Shapes bên trái, tìm nhóm **Entity Relationship**.
2. Bấm nút **Import** ở góc bảng shapes $\rightarrow$ Chọn hệ quản trị **PostgreSQL**.
3. Sao chép toàn bộ khối mã **SQL DDL** ở Mục 3 dán vào.
4. Lucidchart sẽ tự động tạo bảng, các trường dữ liệu (PK, FK, data types) và tự nối các đường quan hệ 1-N chính xác 100%.

### Cách 4: Dùng trực tiếp cho "Lucidchart AI Prompt" (Nhắc lệnh AI)
- Ở mỗi mục sơ đồ bên dưới đều có sẵn đoạn văn bản **Prompt AI** (bằng cả tiếng Việt và tiếng Anh). Bạn chỉ cần bấm vào nút **Generate with AI** (biểu tượng tia sét/ngôi sao) của Lucidchart rồi dán đoạn Prompt đó vào.

---

## 1. SƠ ĐỒ NGỮ CẢNH HỆ THỐNG (SYSTEM CONTEXT DIAGRAM)

### 1.1. Mã PlantUML
```plantuml
@startuml
!theme plain
skinparam defaultFontName "Segoe UI"
skinparam roundCorner 10
skinparam actorBorderColor #1A365D
skinparam actorBackgroundColor #EBF8FF
skinparam rectangleBorderColor #2B6CB0
skinparam rectangleBackgroundColor #F7FAFC

actor "Cư dân\n(Resident)" as Resident #EBF8FF
actor "Ban Quản Lý\n(Management)" as BQL #FEFCBF
actor "Kế toán\n(Accountant)" as Accountant #C6F6D5
actor "Kỹ thuật viên\n(Technician)" as Technician #E9D8FD
actor "Quản trị viên\n(Admin)" as Admin #FED7D7

rectangle "HỆ THỐNG QUẢN LÝ CHUNG CƯ PKA-HOME\n(Ứng dụng Flutter + Máy chủ Supabase BaaS)" as PKA_Home #2B6CB0;text:white {
    note "• Quản lý Căn hộ chuẩn A0110\n• Đặt tiện ích & Sức chứa động\n• Hóa đơn & Thanh toán VietQR\n• Tiếp nhận sự cố & Nghiệm thu ảnh\n• Thông báo phân nhóm đích" as CoreNote
}

cloud "Cơ sở dữ liệu PostgreSQL 15\n(Supabase Database + RPC + RLS)" as SupabaseDB #EDF2F7
cloud "Kho lưu trữ tệp tin riêng tư\n(Supabase Private Storage)" as Storage #EDF2F7
cloud "Cổng thanh toán điện tử mô phỏng\n(VietQR / Banking Gateway)" as PaymentGW #EDF2F7
cloud "Dịch vụ gửi thông báo đẩy\n(Firebase Cloud Messaging - FCM)" as FCM #EDF2F7

Resident --> PKA_Home : (1) Gửi yêu cầu liên kết căn hộ\n(2) Khai báo chỉ số điện nước & ảnh\n(3) Đặt lịch tiện ích / Tự hủy an toàn\n(4) Thanh toán hóa đơn (VietQR/CK)\n(5) Báo phản ánh sự cố kỹ thuật
BQL --> PKA_Home : (1) Phê duyệt liên kết căn hộ\n(2) Duyệt hồ sơ phương tiện xe\n(3) Quản trị tiện ích 3 Tab & Check-in\n(4) Phát hành thông báo phân nhóm
Accountant --> PKA_Home : (1) Thẩm định ảnh công tơ điện nước\n(2) Lập hóa đơn hàng loạt (Preflight)\n(3) Đối soát & Ghi nhận nộp tiền mặt
Technician --> PKA_Home : (1) Tiếp nhận phân công sự cố\n(2) Đính kèm ảnh minh chứng nghiệm thu
Admin --> PKA_Home : (1) Phân quyền RBAC & Ủy quyền vai trò\n(2) Giám sát nhật ký kiểm toán (Audit Trail)

PKA_Home <--> SupabaseDB : Thực thi truy vấn, RPC nguyên tử\nvà chính sách bảo mật cấp bản ghi RLS
PKA_Home --> Storage : Tải và đọc ảnh công tơ, ảnh sự cố, ảnh thẻ xe
PKA_Home --> PaymentGW : Tạo mã QR động và xác thực giao dịch
PKA_Home --> FCM : Gửi thông báo khẩn cấp tới thiết bị
@enduml
```

### 1.2. Prompt cho Lucidchart AI
> **Prompt:**  
> "Vẽ Sơ đồ Ngữ cảnh Hệ thống (System Context Diagram) cho ứng dụng Quản lý Chung cư PKA-Home. Ở trung tâm là hệ thống PKA-Home (Ứng dụng Flutter kết hợp Backend Supabase). Xung quanh có 5 tác nhân người dùng: Cư dân, Ban Quản Lý, Kế toán, Kỹ thuật viên, Quản trị viên. Hệ thống kết nối với 4 dịch vụ máy chủ bên ngoài: Cơ sở dữ liệu PostgreSQL (chứa RLS và RPC), Kho lưu trữ tệp tin Supabase Storage (lưu ảnh công tơ và sự cố), Cổng thanh toán mô phỏng VietQR, và Dịch vụ gửi thông báo đẩy Firebase Cloud Messaging. Các đường mũi tên có nhãn mô tả rõ nghiệp vụ trao đổi dữ liệu."

---

## 2. SƠ ĐỒ CA SỬ DỤNG TỔNG QUAN & CHI TIẾT (USE CASE DIAGRAM)

### 2.1. Phân hệ Cư Dân (Resident Use Cases - 12 Use Cases)
#### Mã PlantUML
```plantuml
@startuml
!theme plain
left to right direction
skinparam defaultFontName "Segoe UI"
skinparam packageStyle rectangle
skinparam actorBorderColor #1A365D
skinparam actorBackgroundColor #EBF8FF
skinparam usecaseBackgroundColor #F7FAFC
skinparam usecaseBorderColor #2B6CB0

actor "Cư dân\n(Resident)" as Resident

rectangle "Phân Hệ Cư Dân PKA-Home" {
    usecase "UC-R01: Đăng ký & Đăng nhập tài khoản" as UCR01
    usecase "UC-R02: Xin liên kết căn hộ chuẩn A0110" as UCR02
    usecase "UC-R03: Xem bảng tin & Thông báo đích" as UCR03
    usecase "UC-R04: Tra cứu chi tiết hóa đơn sinh hoạt" as UCR04
    usecase "UC-R05: Thanh toán mô phỏng hai bước (VietQR)" as UCR05
    usecase "UC-R06: Khai báo chỉ số điện nước kèm ảnh" as UCR06
    usecase "UC-R07: Đặt lịch tiện ích & Chọn số khách" as UCR07
    usecase "UC-R08: Tự hủy lịch tiện ích an toàn (Atomic RPC)" as UCR08
    usecase "UC-R09: Đăng ký thẻ xe & Báo hủy xe" as UCR09
    usecase "UC-R10: Báo phản ánh sự cố kỹ thuật kèm ảnh" as UCR10
    usecase "UC-R11: Chấm điểm đánh giá kỹ thuật 1-5 sao" as UCR11
    usecase "UC-R12: Tra cứu cẩm nang & Hotline khẩn cấp" as UCR12

    usecase "Tự động xếp vào Danh sách chờ (Waitlist)" as UC_Waitlist #FFF5F5;line:red
    usecase "Đổi căn hộ sở hữu (Apartment Switcher)" as UC_Switch #EDF2F7
}

Resident --> UCR01
Resident --> UCR02
Resident --> UCR03
Resident --> UCR04
Resident --> UCR05
Resident --> UCR06
Resident --> UCR07
Resident --> UCR08
Resident --> UCR09
Resident --> UCR10
Resident --> UCR11
Resident --> UCR12

UCR07 ..> UC_Waitlist : <<extend>> (khi kín sức chứa)
UCR04 ..> UC_Switch : <<include>>
UCR10 ..> UCR11 : <<trigger>> (khi sự cố hoàn thành)
@enduml
```

### 2.2. Phân hệ Ban Quản Lý & Vận Hành (Management Use Cases - 13 Use Cases)
#### Mã PlantUML
```plantuml
@startuml
!theme plain
left to right direction
skinparam defaultFontName "Segoe UI"
skinparam packageStyle rectangle
skinparam actorBorderColor #2D3748
skinparam usecaseBackgroundColor #F7FAFC
skinparam usecaseBorderColor #2F855A

actor "Quản trị viên\n(Admin)" as Admin #FED7D7
actor "Ban Quản Lý\n(Manager)" as Manager #FEFCBF
actor "Kế toán\n(Accountant)" as Accountant #C6F6D5
actor "Kỹ thuật viên\n(Technician)" as Technician #E9D8FD

rectangle "Phân Hệ Ban Quản Lý & Vận Hành PKA-Home" {
    usecase "UC-M01: Quản lý danh mục căn hộ chuẩn A0110" as UCM01
    usecase "UC-M02: Thẩm định & Duyệt liên kết căn hộ" as UCM02
    usecase "UC-M03: Thẩm định ảnh công tơ điện nước" as UCM03
    usecase "UC-M04: Lập hóa đơn hàng loạt có Preflight" as UCM04
    usecase "UC-M05: Đối soát thanh toán & Thu tiền mặt" as UCM05
    usecase "UC-M06: Thẩm định & Duyệt thẻ gửi xe" as UCM06
    
    package "Quản trị Tiện ích 3 Tab" #F0FFF4 {
        usecase "UC-M07a: Duyệt lịch & Từ chối kèm lý do (Tab 1)" as UCM07a
        usecase "UC-M07b: Cấu hình Tiện ích & Sức chứa động (Tab 2)" as UCM07b
        usecase "UC-M07c: Quản lý Lịch bảo trì tiện ích (Tab 3)" as UCM07c
    }
    usecase "UC-M08: Điểm danh Check-in khách (Mã/QR)" as UCM08
    usecase "UC-M09: Tiếp nhận & Phân công kỹ thuật viên" as UCM09
    usecase "UC-M10: Nghiệm thu sự cố kèm ảnh minh chứng" as UCM10
    usecase "UC-M11: Phát hành thông báo phân nhóm đích" as UCM11
    usecase "UC-M12: Quản trị thiết bị & Bảo trì tòa nhà" as UCM12
    usecase "UC-M13: Phân quyền RBAC & Ủy quyền vai trò" as UCM13
}

Manager --> UCM01
Manager --> UCM02
Manager --> UCM06
Manager --> UCM07a
Manager --> UCM07b
Manager --> UCM07c
Manager --> UCM08
Manager --> UCM09
Manager --> UCM11

Accountant --> UCM03
Accountant --> UCM04
Accountant --> UCM05

Technician --> UCM10
Technician --> UCM12

Admin --|> Manager
Admin --> UCM13
@enduml
```

### 2.3. Prompt cho Lucidchart AI
> **Prompt:**  
> "Vẽ Sơ đồ Use Case chuẩn UML cho hệ thống quản lý chung cư PKA-Home gồm 2 phân hệ rõ ràng: Phân hệ Cư dân (12 ca sử dụng: đăng ký, liên kết căn hộ A0110, nhận thông báo đích, xem hóa đơn, thanh toán VietQR, nộp chỉ số điện nước kèm ảnh, đặt lịch tiện ích theo số người, tự hủy lịch tiện ích, đăng ký xe, báo sự cố, đánh giá 5 sao, cẩm nang) và Phân hệ Quản trị (13 ca sử dụng: duyệt liên kết, kiểm tra ảnh công tơ, lập hóa đơn hàng loạt có bước Preflight, đối soát thu tiền, duyệt xe, phân hệ Tiện ích 3 Tab gồm duyệt lịch A7/A8, cấu hình sức chứa động, lịch bảo trì, quét QR check-in, phân công kỹ thuật, nghiệm thu đính kèm ảnh, phát thông báo theo Block/Tầng/Căn hộ, và phân quyền RBAC)."

---

## 3. SƠ ĐỒ QUAN HỆ THỰC THỂ CƠ SỞ DỮ LIỆU (ERD - 16 BẢNG)

### 3.1. Mã PostgreSQL DDL (Nhập trực tiếp vào tính năng ERD của Lucidchart)
*Cách dùng:* Mở Lucidchart $\rightarrow$ Shapes (bên trái) $\rightarrow$ Entity Relationship $\rightarrow$ **Import** $\rightarrow$ Chọn **PostgreSQL** $\rightarrow$ Dán toàn bộ mã dưới đây $\rightarrow$ Lucidchart tự động dựng bảng và nối dây quan hệ:

```sql
-- 1. Bảng người dùng
CREATE TABLE users (
    id UUID PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100) UNIQUE NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'resident',
    is_locked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Bảng căn hộ
CREATE TABLE apartments (
    id UUID PRIMARY KEY,
    code VARCHAR(10) UNIQUE NOT NULL,
    building_code VARCHAR(10) NOT NULL,
    floor_number INTEGER NOT NULL,
    area NUMERIC(8,2) NOT NULL,
    is_empty BOOLEAN DEFAULT TRUE,
    electric_reading NUMERIC(10,2) DEFAULT 0,
    water_reading NUMERIC(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Quan hệ cư dân - căn hộ
CREATE TABLE residents_apartments (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    relation_role VARCHAR(20) NOT NULL DEFAULT 'tenant',
    is_verified BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Yêu cầu liên kết căn hộ
CREATE TABLE apartment_link_requests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    requested_relation_role VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Hóa đơn
CREATE TABLE invoices (
    id UUID PRIMARY KEY,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    period VARCHAR(7) NOT NULL,
    due_date DATE NOT NULL,
    total_amount NUMERIC(12,2) DEFAULT 0,
    status VARCHAR(25) NOT NULL DEFAULT 'unpaid',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Chi tiết hạng mục phí hóa đơn
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    fee_type VARCHAR(50) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    quantity NUMERIC(8,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Khai báo chỉ số điện nước
CREATE TABLE meter_reading_submissions (
    id UUID PRIMARY KEY,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    submitted_by UUID NOT NULL REFERENCES users(id),
    period VARCHAR(7) NOT NULL,
    electric_reading NUMERIC(10,2) NOT NULL,
    water_reading NUMERIC(10,2) NOT NULL,
    image_url TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Quản lý phương tiện cư dân
CREATE TABLE vehicles (
    id UUID PRIMARY KEY,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_type VARCHAR(20) NOT NULL,
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. Danh mục tiện ích tòa nhà
CREATE TABLE building_amenities (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    booking_type VARCHAR(20) DEFAULT 'shared',
    slot_duration_minutes INTEGER DEFAULT 60,
    fee_amount NUMERIC(12,2) DEFAULT 0,
    deposit_amount NUMERIC(12,2) DEFAULT 0,
    requires_deposit BOOLEAN DEFAULT FALSE,
    max_capacity INTEGER NOT NULL DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. Phiếu đặt chỗ tiện ích
CREATE TABLE amenity_bookings (
    id UUID PRIMARY KEY,
    amenity_id UUID NOT NULL REFERENCES building_amenities(id) ON DELETE RESTRICT,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    booked_by UUID NOT NULL REFERENCES users(id),
    booking_date DATE NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    guests_count INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(25) NOT NULL DEFAULT 'confirmed',
    deposit_status VARCHAR(20) DEFAULT 'none',
    checked_in_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. Giao dịch thanh toán
CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    booking_id UUID REFERENCES amenity_bookings(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    transaction_code VARCHAR(50) UNIQUE,
    proof_image_url TEXT,
    cashier_notes TEXT,
    confirmed_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12. Phản ánh sự cố kỹ thuật
CREATE TABLE issue_reports (
    id UUID PRIMARY KEY,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE RESTRICT,
    reporter_id UUID NOT NULL REFERENCES users(id),
    assigned_staff_id UUID REFERENCES users(id),
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    resolution_proof_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 13. Hình ảnh sự cố
CREATE TABLE issue_images (
    id UUID PRIMARY KEY,
    issue_report_id UUID NOT NULL REFERENCES issue_reports(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 14. Đánh giá chất lượng xử lý sự cố
CREATE TABLE issue_ratings (
    id UUID PRIMARY KEY,
    issue_report_id UUID UNIQUE NOT NULL REFERENCES issue_reports(id) ON DELETE CASCADE,
    rated_by UUID NOT NULL REFERENCES users(id),
    speed_rating INTEGER NOT NULL,
    attitude_rating INTEGER NOT NULL,
    quality_rating INTEGER NOT NULL,
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 15. Thông báo tòa nhà phân nhóm đối tượng
CREATE TABLE announcements (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    is_urgent BOOLEAN DEFAULT FALSE,
    target_type VARCHAR(20) DEFAULT 'ALL',
    target_building VARCHAR(10),
    target_floor INTEGER,
    target_apartment_id UUID REFERENCES apartments(id) ON DELETE SET NULL,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 16. Thiết bị trọng yếu tòa nhà
CREATE TABLE building_equipment (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    equipment_type VARCHAR(50) NOT NULL,
    location VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'operational',
    next_maintenance_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 3.2. Mã Mermaid ERD
```mermaid
erDiagram
    users ||--o{ residents_apartments : "gắn với"
    apartments ||--o{ residents_apartments : "thuộc về"
    users ||--o{ apartment_link_requests : "gửi"
    apartments ||--o{ apartment_link_requests : "tiếp nhận"
    apartments ||--o{ invoices : "phát sinh"
    invoices ||--|{ invoice_items : "chi tiết"
    apartments ||--o{ meter_reading_submissions : "đo đếm"
    users ||--o{ meter_reading_submissions : "nộp"
    apartments ||--o{ vehicles : "đăng ký"
    users ||--o{ vehicles : "sở hữu"
    building_amenities ||--o{ amenity_bookings : "sử dụng"
    apartments ||--o{ amenity_bookings : "đặt bởi"
    invoices ||--o{ payment_transactions : "thanh toán"
    amenity_bookings ||--o{ payment_transactions : "thu cọc"
    apartments ||--o{ issue_reports : "xảy ra tại"
    users ||--o{ issue_reports : "báo cáo"
    issue_reports ||--o{ issue_images : "đính kèm"
    issue_reports ||--o| issue_ratings : "chấm điểm"
    apartments ||--o{ announcements : "nhắm đích"

    users {
        uuid id PK
        string full_name
        string phone
        string email
        string role
        boolean is_locked
    }

    apartments {
        uuid id PK
        string code UK
        string building_code
        int floor_number
        decimal area
        boolean is_empty
        decimal electric_reading
        decimal water_reading
    }

    invoices {
        uuid id PK
        uuid apartment_id FK
        string period
        date due_date
        decimal total_amount
        string status
    }

    building_amenities {
        uuid id PK
        string name
        string booking_type
        int max_capacity
        decimal fee_amount
        decimal deposit_amount
        boolean requires_deposit
    }

    amenity_bookings {
        uuid id PK
        uuid amenity_id FK
        uuid apartment_id FK
        uuid booked_by FK
        date booking_date
        string time_slot
        int guests_count
        string status
        timestamp checked_in_at
    }

    announcements {
        uuid id PK
        string title
        text content
        boolean is_urgent
        string target_type
        string target_building
        int target_floor
        uuid target_apartment_id FK
    }
```

---

## 4. SƠ ĐỒ TUẦN TỰ NGHIỆP VỤ TRỌNG TÂM (SEQUENCE DIAGRAMS)

### 4.1. Tuần tự Đặt Tiện Ích, Xử Lý Sức Chứa Động & Tự Hủy Lịch An Toàn
#### Mã PlantUML
```plantuml
@startuml
!theme plain
autonumber
skinparam defaultFontName "Segoe UI"
skinparam sequenceMessageAlign center

actor "Cư dân\n(Resident)" as CD #EBF8FF
participant "Giao diện Flutter\n(AmenityBookingScreen)" as UI #EDF2F7
participant "AmenityRepository\n(Riverpod)" as Repo #FEFCBF
participant "PostgreSQL Database\n(RPC Stored Procedures)" as DB #C6F6D5
actor "Ban Quản Lý\n(Admin / Staff)" as BQL #FED7D7

== GIAI ĐOẠN 1: ĐẶT LỊCH TIỆN ÍCH & KIỂM TRA SỨC CHỨA ==
CD -> UI : Chọn Tiện ích, Ngày, Khung giờ & Số lượng người (guests_count)
UI -> Repo : bookSlot(amenityId, date, slot, guestsCount, allowWaitlist)
Repo -> DB : Gọi RPC book_amenity_slot(...)
activate DB
DB -> DB : Khóa dòng tiện ích FOR UPDATE\n(Ngăn xung đột đồng thời)
DB -> DB : Tính tổng khách hiện tại: current_capacity
alt current_capacity + guests_count <= max_capacity
    DB -> DB : INSERT vào amenity_bookings\ntrạng thái = 'confirmed'
    DB --> Repo : Trả về: { success: true, status: 'confirmed', booking_id: ... }
    Repo --> UI : Hiển thị: "Đặt chỗ thành công!"
else Vượt quá sức chứa và Cư dân đồng ý chờ
    DB -> DB : INSERT vào amenity_bookings\ntrạng thái = 'waitlist'
    DB --> Repo : Trả về: { success: true, status: 'waitlist', booking_id: ... }
    Repo --> UI : Hiển thị: "Đã ghi danh vào Danh sách chờ (Waitlist)"
else Hết chỗ và không đồng ý chờ
    DB --> Repo : Báo lỗi: "Khung giờ đã kín chỗ"
    Repo --> UI : Thông báo lỗi hết chỗ
end
deactivate DB

== GIAI ĐOẠN 2: CƯ DÂN TỰ HỦY LỊCH AN TOÀN (ATOMIC RPC) ==
CD -> UI : Bấm nút "HỦY LỊCH ĐẶT CHỖ"
UI -> Repo : cancelBooking(bookingId)
Repo -> DB : Gọi RPC cancel_amenity_booking(p_booking_id)
activate DB
DB -> DB : Kiểm tra quyền sở hữu (booked_by = auth.uid() OR is_management())
DB -> DB : Cập nhật booking.status = 'cancelled'
DB -> DB : Cập nhật payment_transactions.status = 'cancelled' (nếu có cọc)
DB -> DB : Tìm phiếu tiếp theo trong danh sách chờ (Waitlist FIFO)
alt Có người trong danh sách chờ vừa đủ chỗ
    DB -> DB : Tự động đôn phiếu chờ lên status = 'confirmed'
end
DB --> Repo : Trả về: { success: true, promoted_booking_id: ... }
deactivate DB
Repo --> UI : Cập nhật danh sách lịch đặt tức thì (Realtime/Refetch)
UI --> CD : Thông báo: "Đã hủy lịch đặt chỗ thành công!"

== GIAI ĐOẠN 3: ĐIỂM DANH CHECK-IN TẠI QUẦY ==
CD -> BQL : Xuất trình mã đặt chỗ hoặc mã QR
BQL -> UI : Bấm "Điểm danh Check-in" trên Tab 1 Duyệt lịch
UI -> Repo : checkInBooking(bookingId)
Repo -> DB : UPDATE amenity_bookings SET status='checked_in', checked_in_at=NOW()
DB --> UI : Xác nhận Check-in thành công
@enduml
```

### 4.2. Tuần tự Khai Báo Chỉ Số Điện Nước & Thanh Toán Hai Bước (VietQR)
#### Mã PlantUML
```plantuml
@startuml
!theme plain
autonumber
skinparam defaultFontName "Segoe UI"
skinparam sequenceMessageAlign center

actor "Cư dân\n(Resident)" as CD #EBF8FF
participant "Flutter UI" as UI #EDF2F7
participant "Repositories" as Repo #FEFCBF
participant "PostgreSQL Database\n(RPC & Trigger)" as DB #C6F6D5
actor "Kế toán\n(Accountant)" as KT #FED7D7

== 1. KHAI BÁO CHỈ SỐ ĐIỆN NƯỚC HÀNG THÁNG ==
CD -> UI : Chụp ảnh công tơ thực tế & Nhập số đo mới
UI -> Repo : submitMeterReading(aptId, electricVal, waterVal, imageFile)
Repo -> DB : INSERT meter_reading_submissions (status = 'pending')
DB --> UI : Thông báo đã gửi chỉ số thành công

== 2. KẾ TOÁN THẨM ĐỊNH & TỰ ĐỘNG XUẤT HÓA ĐƠN ==
KT -> UI : Mở màn hình Thẩm định, so sánh ảnh công tơ
KT -> UI : Bấm "Phê duyệt & Xuất hóa đơn kỳ"
UI -> Repo : approveMeterReading(submissionId, autoInvoice=true)
Repo -> DB : Gọi RPC approve_meter_reading(...)
activate DB
DB -> DB : Khóa dòng FOR UPDATE\nKiểm tra: new_reading >= old_reading
DB -> DB : Cập nhật electric_reading và water_reading vào apartments
DB -> DB : Tự động tạo invoice + invoice_items (Điện, Nước)
DB -> DB : Trigger trg_recalc_invoice_total tự tính total_amount
DB --> Repo : Trả về ID hóa đơn mới tạo
deactivate DB
Repo --> UI : Cập nhật danh sách hóa đơn kỳ

== 3. THANH TOÁN MÔ PHỎNG & ĐỐI SOÁT HAI BƯỚC ==
CD -> UI : Mở chi tiết hóa đơn, chọn phương thức VietQR/Chuyển khoản
UI -> Repo : pay(invoiceId, method, amount)
Repo -> DB : Gọi RPC simulate_unified_payment(...)
activate DB
DB -> DB : Tạo payment_transactions (status = 'pending')
DB -> DB : Cập nhật invoices.status = 'pending_confirmation'
DB --> Repo : Trả về mã giao dịch
deactivate DB
Repo --> UI : Hiển thị màn hình chờ kế toán đối soát

KT -> UI : Mở màn hình Quản lý hóa đơn, kiểm tra ủy nhiệm chi
KT -> UI : Bấm "Duyệt thanh toán"
UI -> Repo : recordManualPayment(invoiceId, amount, notes)
Repo -> DB : Cập nhật invoices.status = 'paid' & transaction.status = 'success'
DB --> UI : Hoàn tất đối soát, hóa đơn gạch nợ thành công
@enduml
```

---

## 5. SƠ ĐỒ HOẠT ĐỘNG NGHIỆP VỤ (ACTIVITY DIAGRAMS)

### 5.1. Hoạt động Đặt Tiện Ích, Sức Chứa Động & Tự Hủy Lịch
#### Mã PlantUML
```plantuml
@startuml
!theme plain
skinparam defaultFontName "Segoe UI"
skinparam ConditionEndStyle hline

|Cư dân|
start
:Mở màn hình Đặt lịch tiện ích;
:Chọn Tiện ích (Bể bơi, Gym, BBQ, Tennis);
:Chọn Ngày sử dụng & Số người tham gia (guests_count);
:Chọn Khung giờ hoạt động còn trống;

|Hệ thống Máy chủ (PostgreSQL RPC)|
:Khóa tiện ích theo khung giờ (FOR UPDATE);
:Đếm tổng số người đã đặt: current_capacity;

if (current_capacity + guests_count <= max_capacity?) then (Còn chỗ)
    :Tạo booking ở trạng thái CONFIRMED;
    |Cư dân|
    :Nhận thông báo "Đặt chỗ thành công";
    if (Cư dân đổi ý muốn hủy lịch?) then (Có nhu cầu hủy)
        :Bấm nút "HỦY LỊCH ĐẶT CHỖ";
        |Hệ thống Máy chủ (PostgreSQL RPC)|
        :Gọi RPC cancel_amenity_booking;
        :Chuyển trạng thái booking sang CANCELLED;
        :Hủy giao dịch cọc liên quan (nếu có);
        if (Có phiếu trong Danh sách chờ (Waitlist)?) then (Có)
            :Đôn phiếu chờ đầu tiên lên CONFIRMED;
            :Gửi thông báo cho cư dân được đôn;
        else (Không có ai chờ)
            :Giải phóng chỗ trống;
        endif
        |Cư dân|
        :Nhận thông báo "Đã hủy lịch an toàn";
    else (Sử dụng bình thường)
        |Ban Quản Lý|
        :Quét QR hoặc nhập mã Điểm danh Check-in;
    endif
else (Hết chỗ)
    |Cư dân|
    if (Đồng ý đăng ký vào Danh sách chờ?) then (Đồng ý)
        |Hệ thống Máy chủ (PostgreSQL RPC)|
        :Tạo booking ở trạng thái WAITLIST;
        |Cư dân|
        :Nhận thông báo "Đã ghi danh danh sách chờ";
    else (Không đồng ý)
        |Cư dân|
        :Chọn khung giờ khác hoặc thoát;
    endif
endif

stop
@enduml
```

### 5.2. Hoạt động Thẩm Định Chỉ Số & Lập Hóa Đơn Hàng Loạt (Preflight)
#### Mã PlantUML
```plantuml
@startuml
!theme plain
skinparam defaultFontName "Segoe UI"

|Kế toán / BQL|
start
:Mở tính năng "Lập hóa đơn hàng loạt";
:Chọn Kỳ hóa đơn (VD: 10/2026), ngày đến hạn & đơn giá;
:Bấm nút "Kiểm tra trước dữ liệu (Preflight Check)";

|Hệ thống Máy chủ|
:Quét toàn bộ danh sách căn hộ trong tòa nhà;
:Kiểm tra các căn hộ đã có hóa đơn trong kỳ (ngăn trùng);
:Đếm số lượng xe máy, ô tô đã duyệt của từng căn hộ;
:Tính toán tổng tiền dự kiến toàn tòa nhà;

|Kế toán / BQL|
:Xem Bảng tổng hợp Preflight Dialog;
note right
    Hiển thị rõ:
    • Số căn hộ hợp lệ
    • Số căn hộ bị bỏ qua (đã có hóa đơn)
    • Tổng tiền dự kiến
end note

if (Xác nhận phát hành?) then (Đồng ý)
    |Hệ thống Máy chủ|
    :Kích hoạt RPC generate_valid_bulk_invoices;
    :Tạo hóa đơn mẹ invoices cho từng căn hộ;
    :Tạo các invoice_items (Phí quản lý, Phí xe, Điện nước);
    :Trigger tự động tính tổng tiền hóa đơn;
    |Kế toán / BQL|
    :Nhận kết quả: "Phát hành thành công 100% căn hộ";
else (Hủy bỏ)
    :Đóng hộp thoại, không có hóa đơn nào được tạo;
endif

stop
@enduml
```

---

## 6. SƠ ĐỒ TRẠNG THÁI VÒNG ĐỜI THỰC THỂ (STATE MACHINE DIAGRAMS)

### 6.1. Mã Mermaid State Diagram (Cả 3 Vòng Đời: Hóa Đơn, Tiện Ích, Sự Cố)
```mermaid
stateDiagram-v2
    [*] --> Unpaid: Lập hóa đơn mới

    state "VÒNG ĐỜI HÓA ĐƠN" as InvoiceLifecycle {
        Unpaid --> PendingConfirmation: Cư dân nộp ủy nhiệm chi
        Unpaid --> Paid: Thu tiền mặt tại quầy / VietQR
        PendingConfirmation --> Paid: Kế toán phê duyệt
        PendingConfirmation --> Unpaid: Kế toán từ chối chứng từ
        Unpaid --> Overdue: Quá ngày đến hạn
        Overdue --> Paid: Thanh toán trễ hạn
    }

    state "VÒNG ĐỜI LỊCH ĐẶT TIỆN ÍCH" as AmenityLifecycle {
        [*] --> Confirmed: Còn chỗ trống
        [*] --> Waitlist: Hết chỗ (chờ đôn)
        Confirmed --> CheckedIn: Điểm danh tại sảnh
        Waitlist --> Confirmed: Có người hủy, được đôn lên
        Confirmed --> Cancelled: Cư dân/BQL tự hủy (cancel_amenity_booking)
        Waitlist --> Cancelled: Hủy không chờ nữa
        Confirmed --> NoShow: Không đến sử dụng
        CheckedIn --> Completed: Hết giờ hoạt động
    }

    state "VÒNG ĐỜI PHẢN ÁNH SỰ CỐ" as IssueLifecycle {
        [*] --> Pending: Cư dân gửi phản ánh
        Pending --> Assigned: BQL gán Kỹ thuật viên
        Assigned --> InProgress: Kỹ thuật viên bắt đầu sửa
        InProgress --> Completed: Kỹ thuật viên nộp ảnh nghiệm thu
        Completed --> Closed: Cư dân đánh giá 1-5 sao
    }
```

---

## 7. SƠ ĐỒ KIẾN TRÚC PHÂN TẦNG PHẦN MỀM (LAYERED ARCHITECTURE)

### 7.1. Mã PlantUML Component Diagram
```plantuml
@startuml
!theme plain
skinparam defaultFontName "Segoe UI"
skinparam componentStyle uml2

package "TẦNG TRÌNH DIỄN (PRESENTATION LAYER - FLUTTER)" #EBF8FF {
    [Màn hình Cư dân\n(Home, Invoice, Issue, Amenity, Vehicle)] as ResScreens
    [Màn hình Ban Quản Lý\n(Dashboard, 3-Tab Amenity, Bulk Invoices, RBAC)] as MgmtScreens
    [Thành phần dùng chung\n(AppCard, StatusBadge, ShimmerLoading, ErrorView)] as CoreWidgets
    [Hệ thống Theme & Trợ năng\n(Light/Dark Mode, FontSizeScaleProvider)] as ThemeSystem
}

package "TẦNG TRẠNG THÁI (STATE MANAGEMENT - RIVERPOD)" #FEFCBF {
    [AuthNotifier & UserProfileProvider] as AuthProvider
    [InvoiceListProvider & PaymentNotifier] as InvoiceProvider
    [AmenityBookingNotifier & CapacityProvider] as AmenityProvider
    [IssueReportNotifier & RatingProvider] as IssueProvider
    [TargetedAnnouncementProvider] as AnnouncementProvider
}

package "TẦNG DỮ LIỆU & ÁNH XẠ (DATA & REPOSITORY LAYER)" #C6F6D5 {
    [AuthRepository] as AuthRepo
    [InvoiceRepository] as InvoiceRepo
    [AmenityRepository] as AmenityRepo
    [IssueRepository] as IssueRepo
    [AnnouncementRepository] as AnnouncementRepo
    [Data Models (DTO / fromJson - toJson)] as Models
}

package "TẦNG MÁY CHỦ & AN TOÀN (SUPABASE BACKEND CLOUD)" #FED7D7 {
    [Supabase Auth (JWT & Roles)] as SupaAuth
    [Hàm lưu trữ RPC nguyên tử\n(book_amenity_slot, cancel_amenity_booking,\ngenerate_valid_bulk_invoices, approve_meter_reading)] as RPCs
    [Chính sách Phân quyền cấp bản ghi (RLS Policies)\nFail-Closed Security] as RLS
    [PostgreSQL Triggers & Generated Columns\n(trg_prevent_role_escalation, trg_recalc_invoice_total)] as Triggers
    [Private Storage Buckets\n(meter-images, issue-images, proof)] as Buckets
}

ResScreens --> CoreWidgets
MgmtScreens --> CoreWidgets
ResScreens --> ThemeSystem
MgmtScreens --> ThemeSystem

ResScreens --> AuthProvider
ResScreens --> InvoiceProvider
ResScreens --> AmenityProvider
ResScreens --> IssueProvider
ResScreens --> AnnouncementProvider

MgmtScreens --> AuthProvider
MgmtScreens --> InvoiceProvider
MgmtScreens --> AmenityProvider
MgmtScreens --> IssueProvider
MgmtScreens --> AnnouncementProvider

AuthProvider --> AuthRepo
InvoiceProvider --> InvoiceRepo
AmenityProvider --> AmenityRepo
IssueProvider --> IssueRepo
AnnouncementProvider --> AnnouncementRepo

AuthRepo --> Models
InvoiceRepo --> Models
AmenityRepo --> Models
IssueRepo --> Models
AnnouncementRepo --> Models

AuthRepo --> SupaAuth
InvoiceRepo --> RPCs
AmenityRepo --> RPCs
IssueRepo --> Buckets
AnnouncementRepo --> RLS

RPCs --> Triggers
RLS --> Triggers
@enduml
```

---

## 8. SƠ ĐỒ TRIỂN KHAI HẠ TẦNG VÀ DỊCH VỤ (DEPLOYMENT DIAGRAM)

### 8.1. Mã PlantUML Deployment Diagram
```plantuml
@startuml
!theme plain
skinparam defaultFontName "Segoe UI"

node "Thiết bị Di động Cư dân\n(Android OS 10.0+)" as MobileResident #EBF8FF {
    artifact "PKA-Home Mobile App\n(Flutter Release APK)" as ResidentAPK
}

node "Máy trạm Ban Quản Lý\n(Android Tablet / Desktop Chrome Web)" as AdminDevice #FEFCBF {
    artifact "PKA-Home Management Console\n(Flutter Web / Desktop App)" as AdminWeb
}

cloud "HẠ TẦNG ĐÁM MÂY SUPABASE (CLOUD BAAS)" #EDF2F7 {
    node "Cổng giao tiếp API (Kong API Gateway)" as Gateway #CBD5E0 {
        [Reverse Proxy & SSL Termination] as Proxy
    }

    node "Dịch vụ Xác thực (GoTrue Auth Server)" as AuthService #CBD5E0 {
        [JWT Token Issuer & Verifier] as JWT
    }

    node "Máy chủ Cơ sở dữ liệu (PostgreSQL 15 Managed Engine)" as DBServer #C6F6D5 {
        database "PKA-Home Relational DB\n(16 Tables, RLS, Triggers, RPCs)" as PostgresDB
    }

    node "Dịch vụ Thời gian thực (Realtime Server)" as Realtime #CBD5E0 {
        [WebSocket Broadcast Engine] as WS
    }

    node "Vùng lưu trữ tệp (S3 Compatible Storage)" as StorageService #CBD5E0 {
        folder "Private Buckets\n(meter-images, issue-images)" as S3Buckets
    }
}

cloud "Dịch vụ Thông báo (Firebase Cloud Messaging)" as FCMService #FED7D7
cloud "Ngân hàng Thương mại (VietQR Simulation)" as VietQRService #FED7D7

ResidentAPK --down-> Proxy : HTTPS / REST (PostgREST)
ResidentAPK --down-> WS : WSS (Realtime Subscriptions)
AdminWeb --down-> Proxy : HTTPS / REST
AdminWeb --down-> WS : WSS

Proxy --> AuthService : Xác thực danh tính
Proxy --> PostgresDB : Thực thi truy vấn & RPC
Proxy --> S3Buckets : Upload / Download ảnh bảo mật

PostgresDB ..> FCMService : Webhook kích hoạt thông báo
ResidentAPK ..> VietQRService : Tạo mã quét QR thanh toán
@enduml
```

### 8.2. Prompt cho Lucidchart AI
> **Prompt:**  
> "Vẽ Sơ đồ Triển khai (Deployment Diagram) chuẩn UML thể hiện cấu trúc phân tán của ứng dụng Quản lý Chung cư PKA-Home: Thiết bị di động của Cư dân chạy Flutter APK kết nối qua HTTPS/WSS tới Nền tảng Đám mây Supabase Cloud. Máy trạm Ban Quản lý kết nối qua Web Browser. Cụm máy chủ Supabase Cloud gồm API Gateway Kong, Dịch vụ xác thực GoTrue, Cơ sở dữ liệu quan hệ PostgreSQL 15 (với RLS và RPC), Dịch vụ WebSocket Realtime và Vùng lưu trữ tệp riêng tư S3 Storage. Hệ thống đồng thời tích hợp với Firebase Cloud Messaging để đẩy thông báo và Cổng VietQR để tạo mã quét thanh toán."

---

## KẾT LUẬN & BẢN QUYỀN TÀI LIỆU

Tài liệu này bao gồm đầy đủ mã nguồn chuẩn hóa (PlantUML, Mermaid, PostgreSQL DDL) và câu lệnh nhắc (AI Prompts) cho mọi loại sơ đồ kỹ thuật cần thiết trong đồ án liên ngành PKA-Home. Bạn có thể sử dụng bất kỳ sơ đồ nào để import trực tiếp vào Lucidchart chỉ trong 1 thao tác copy-paste mà không lo sai lệch cú pháp hoặc bị thiếu trường dữ liệu.
