import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import os

plt.rcParams['font.sans-serif'] = ['Segoe UI', 'Arial', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False
out_dir = r'c:/Users/ADMIN/StudioProjects/pka_home/docs/report_assets'
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------
# 1. Use Case Cư dân
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10.5, 6.5), dpi=220)
ax.axis('off')
ax.set_xlim(0, 10.5)
ax.set_ylim(0, 8.2)

ax.text(5.25, 7.8, 'SƠ ĐỒ CA SỬ DỤNG - PHÂN HỆ CƯ DÂN (PKA-HOME)', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

# Actor box
actor_box = patches.FancyBboxPatch((0.4, 3.0), 1.8, 2.0, boxstyle='round,pad=0.2', facecolor='#EBF8FF', edgecolor='#3182CE', linewidth=2)
ax.add_patch(actor_box)
ax.text(1.3, 4.2, '[ ACTOR ]', fontsize=11, fontweight='bold', ha='center', va='center', color='#2B6CB0')
ax.text(1.3, 3.6, 'CƯ DÂN\n(RESIDENT)', fontsize=10, fontweight='bold', ha='center', va='center', color='#1A365D')

# Boundary
boundary = patches.Rectangle((2.8, 0.4), 7.3, 7.0, fill=False, edgecolor='#A0AEC0', linewidth=1.5, linestyle='--')
ax.add_patch(boundary)
ax.text(3.0, 7.1, 'Ranh giới hệ thống ứng dụng di động Cư dân', fontsize=9, fontstyle='italic', color='#718096')

use_cases = [
    'UC-R01: Đăng ký & Đăng nhập tài khoản bảo mật',
    'UC-R02: Gửi yêu cầu liên kết mã căn hộ (chuẩn A0110)',
    'UC-R03: Xem bảng tin tổng quan & Nhận thông báo tòa nhà',
    'UC-R04: Tra cứu hóa đơn dịch vụ & Chi tiết từng khoản phí',
    'UC-R05: Thanh toán mô phỏng (VietQR, Chuyển khoản ngân hàng)',
    'UC-R06: Khai báo chỉ số công tơ điện nước & Chụp ảnh minh chứng',
    'UC-R07: Đặt lịch tiện ích chung cư & Quản lý danh sách chờ',
    'UC-R08: Đăng ký phương tiện cư dân (Giới hạn xe máy, ô tô)',
    'UC-R09: Gửi phản ánh sự cố kỹ thuật & Trao đổi bình luận',
    'UC-R10: Chấm điểm đánh giá chất lượng dịch vụ (1 - 5 sao)',
    'UC-R11: Tra cứu cẩm nang cư dân, nội quy & Danh bạ khẩn cấp'
]

y_positions = np.linspace(6.5, 0.8, len(use_cases))
for y, uc in zip(y_positions, use_cases):
    ellipse = patches.FancyBboxPatch((3.4, y-0.22), 6.3, 0.44, boxstyle='round,pad=0.15', facecolor='#F7FAFC', edgecolor='#4A5568', linewidth=1.2)
    ax.add_patch(ellipse)
    ax.text(6.55, y, uc, ha='center', va='center', fontsize=8.5, color='#2D3748', fontweight='bold')
    ax.annotate('', xy=(3.4, y), xytext=(2.2, 4.0), arrowprops=dict(arrowstyle='->', color='#3182CE', lw=1.2))

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_2a_use_case_cu_dan.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 2. Use Case Ban Quản Lý & Vận hành
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 7.5), dpi=220)
ax.axis('off')
ax.set_xlim(0, 11)
ax.set_ylim(0, 8.5)

ax.text(5.5, 8.1, 'SƠ ĐỒ CA SỬ DỤNG - PHÂN HỆ BAN QUẢN LÝ & VẬN HÀNH', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

# Actors
actors = [
    ('BAN QUẢN LÝ', 6.2, '#2B6CB0', '#EBF8FF', '#3182CE'),
    ('KẾ TOÁN', 4.3, '#276749', '#F0FFF4', '#38A169'),
    ('KỸ THUẬT VIÊN', 2.4, '#C05621', '#FFFAF0', '#DD6B20'),
    ('QUẢN TRỊ VIÊN', 0.8, '#6B46C1', '#FAF5FF', '#805AD5')
]

for name, y, txt_col, bg_col, bdr_col in actors:
    box = patches.FancyBboxPatch((0.2, y-0.5), 1.9, 1.0, boxstyle='round,pad=0.15', facecolor=bg_col, edgecolor=bdr_col, linewidth=1.8)
    ax.add_patch(box)
    ax.text(1.15, y, name, ha='center', va='center', fontsize=8.5, fontweight='bold', color=txt_col)

# Boundary
boundary = patches.Rectangle((2.6, 0.2), 8.1, 7.6, fill=False, edgecolor='#A0AEC0', linewidth=1.5, linestyle='--')
ax.add_patch(boundary)
ax.text(2.8, 7.5, 'Ranh giới hệ thống Quản lý & Vận hành tòa nhà', fontsize=9, fontstyle='italic', color='#718096')

mgmt_cases = [
    ('UC-M01: Quản lý danh mục căn hộ (chuẩn A0110)', [0, 3]),
    ('UC-M02: Phê duyệt / Từ chối yêu cầu liên kết căn hộ', [0, 3]),
    ('UC-M03: Thẩm định ảnh công tơ & Duyệt chỉ số điện nước', [1, 3]),
    ('UC-M04: Lập hóa đơn đơn lẻ & Phát hành hàng loạt an toàn', [1, 3]),
    ('UC-M05: Xác nhận thanh toán chuyển khoản & Thu tiền mặt tại quầy', [1, 3]),
    ('UC-M06: Phê duyệt / Từ chối đăng ký phương tiện cư dân', [0, 3]),
    ('UC-M07: Quản lý tiện ích, theo dõi lịch đặt & Điểm danh sử dụng', [0, 3]),
    ('UC-M08: Tiếp nhận phản ánh sự cố & Phân công kỹ thuật viên', [0, 2, 3]),
    ('UC-M09: Cập nhật tiến độ xử lý sự cố & Đính kèm minh chứng', [2, 3]),
    ('UC-M10: Soạn thảo & Phát hành thông báo phân nhóm đối tượng', [0, 3]),
    ('UC-M11: Quản lý thiết bị kỹ thuật tòa nhà & Lịch bảo trì', [0, 2, 3]),
    ('UC-M12: Quản trị phân quyền, ủy quyền vai trò & Nhật ký kiểm toán', [3])
]

y_mg = np.linspace(7.1, 0.5, len(mgmt_cases))
actor_y_map = {0: 6.2, 1: 4.3, 2: 2.4, 3: 0.8}
actor_colors = {0: '#3182CE', 1: '#38A169', 2: '#DD6B20', 3: '#805AD5'}

for y, (uc_title, act_idx_list) in zip(y_mg, mgmt_cases):
    ellipse = patches.FancyBboxPatch((3.2, y-0.22), 7.2, 0.44, boxstyle='round,pad=0.15', facecolor='#F7FAFC', edgecolor='#4A5568', linewidth=1.1)
    ax.add_patch(ellipse)
    ax.text(6.8, y, uc_title, ha='center', va='center', fontsize=8.5, color='#1A202C', fontweight='bold')
    
    for aidx in act_idx_list:
        ay = actor_y_map[aidx]
        col = actor_colors[aidx]
        ax.annotate('', xy=(3.2, y), xytext=(2.1, ay), arrowprops=dict(arrowstyle='->', color=col, lw=0.9, alpha=0.85))

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_2b_use_case_ban_quan_ly.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 3. Sơ đồ tuần tự: Thanh toán mô phỏng 2 bước an toàn
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 6.8), dpi=220)
ax.axis('off')
ax.set_xlim(0, 11)
ax.set_ylim(0, 7.5)

ax.text(5.5, 7.1, 'SƠ ĐỒ TUẦN TỰ: THANH TOÁN MÔ PHỎNG VÀ ĐỐI SOÁT HAI BƯỚC', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

participants = [
    ('Cư dân', 1.0, '#3182CE'),
    ('Giao diện Flutter', 3.25, '#4A5568'),
    ('PaymentRepository', 5.5, '#4A5568'),
    ('PostgreSQL (RPC)', 7.75, '#C53030'),
    ('Kế toán / BQL', 10.0, '#276749')
]

for name, x, color in participants:
    box = patches.FancyBboxPatch((x-0.9, 6.2), 1.8, 0.6, boxstyle='round,pad=0.1', facecolor='#EDF2F7', edgecolor=color, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, 6.5, name, ha='center', va='center', fontsize=8.5, fontweight='bold', color=color)
    ax.plot([x, x], [0.6, 6.2], linestyle='--', color='#CBD5E0', linewidth=1.2)

def draw_msg(y, x1, x2, text, is_reply=False, is_call=True):
    style = '--' if is_reply else '-'
    col = '#718096' if is_reply else '#2B6CB0'
    ax.annotate('', xy=(x2, y), xytext=(x1, y), arrowprops=dict(arrowstyle='->', color=col, lw=1.2, linestyle=style))
    mid_x = (x1 + x2) / 2
    ax.text(mid_x, y+0.12, text, ha='center', va='bottom', fontsize=7.8, color='#1A202C', fontweight='medium')

draw_msg(5.8, 1.0, 3.25, '1. Chọn hóa đơn & Phương thức thanh toán')
draw_msg(5.4, 3.25, 5.5, '2. Gọi pay(invoiceId, method, amount)')
draw_msg(5.0, 5.5, 7.75, '3. Gọi RPC simulate_unified_payment')

# Active block on DB
db_block = patches.Rectangle((7.65, 3.8), 0.2, 1.3, facecolor='#FED7D7', edgecolor='#E53E3E')
ax.add_patch(db_block)
ax.text(8.8, 4.45, '[Xử lý máy chủ]\n- Khóa dòng FOR UPDATE\n- Kiểm tra quyền sở hữu\n- Tạo giao dịch PENDING\n- Đổi hóa đơn: pending_confirmation', fontsize=7, color='#9B2C2C', ha='center', va='center', bbox=dict(boxstyle='square,pad=0.2', facecolor='#FFF5F5', edgecolor='#FEB2B2'))

draw_msg(3.6, 7.75, 5.5, '4. Trả về mã giao dịch và trạng thái PENDING', is_reply=True)
draw_msg(3.2, 5.5, 3.25, '5. Cập nhật trạng thái thành công', is_reply=True)
draw_msg(2.8, 3.25, 1.0, '6. Hiển thị: "Đang chờ kế toán xác nhận"', is_reply=True)

draw_msg(2.2, 10.0, 7.75, '7. Kế toán kiểm tra chứng từ & Gọi RPC record_manual_payment')
draw_msg(1.6, 7.75, 10.0, '8. Đổi hóa đơn sang "paid" & Giao dịch "SUCCESS"', is_reply=True)
draw_msg(1.0, 7.75, 3.25, '9. Phát sự kiện Realtime cập nhật hóa đơn đã đóng tiền')
draw_msg(0.7, 3.25, 1.0, '10. Giao diện cư dân tự động chuyển sang thẻ xanh "Đã thanh toán"', is_reply=True)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_13a_tuan_tu_thanh_toan.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 4. Sơ đồ tuần tự: Đặt tiện ích và kiểm soát sức chứa
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10.5, 6.8), dpi=220)
ax.axis('off')
ax.set_xlim(0, 10.5)
ax.set_ylim(0, 7.5)

ax.text(5.25, 7.1, 'SƠ ĐỒ TUẦN TỰ: ĐẶT TIỆN ÍCH VÀ XỬ LÝ SỨC CHỨA ĐỒNG THỜI', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

parts_amenity = [
    ('Cư dân', 1.2, '#3182CE'),
    ('Giao diện Đặt chỗ', 3.8, '#4A5568'),
    ('AmenityRepository', 6.4, '#4A5568'),
    ('PostgreSQL (book_amenity_slot)', 9.2, '#C53030')
]

for name, x, color in parts_amenity:
    box = patches.FancyBboxPatch((x-1.0, 6.2), 2.0, 0.6, boxstyle='round,pad=0.1', facecolor='#EDF2F7', edgecolor=color, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, 6.5, name, ha='center', va='center', fontsize=8.5, fontweight='bold', color=color)
    ax.plot([x, x], [0.6, 6.2], linestyle='--', color='#CBD5E0', linewidth=1.2)

def draw_msg_a(y, x1, x2, text, is_reply=False):
    style = '--' if is_reply else '-'
    col = '#718096' if is_reply else '#2B6CB0'
    ax.annotate('', xy=(x2, y), xytext=(x1, y), arrowprops=dict(arrowstyle='->', color=col, lw=1.2, linestyle=style))
    mid_x = (x1 + x2) / 2
    ax.text(mid_x, y+0.12, text, ha='center', va='bottom', fontsize=7.8, color='#1A202C', fontweight='medium')

draw_msg_a(5.7, 1.2, 3.8, '1. Chọn ngày, khung giờ & Số lượng khách')
draw_msg_a(5.2, 3.8, 6.4, '2. bookSlot(amenityId, date, slot, guests)')
draw_msg_a(4.7, 6.4, 9.2, '3. Gọi RPC book_amenity_slot')

# DB lock block
db_b2 = patches.Rectangle((9.1, 2.5), 0.2, 2.3, facecolor='#FED7D7', edgecolor='#E53E3E')
ax.add_patch(db_b2)
ax.text(7.6, 3.5, '[Xử lý giao dịch máy chủ]\n1. Khóa tài nguyên tiện ích theo ngày/giờ\n2. Đếm tổng khách các booking đã xác nhận\n3. So sánh: current_capacity + guests <= max\n4. Nếu còn: ghi nhận CONFIRMED\n5. Nếu kín & allow_waitlist: ghi nhận WAITLIST', fontsize=7.2, color='#9B2C2C', ha='center', va='center', bbox=dict(boxstyle='square,pad=0.2', facecolor='#FFF5F5', edgecolor='#FEB2B2'))

draw_msg_a(2.1, 9.2, 6.4, '4. Trả về mã đặt chỗ & Trạng thái (CONFIRMED / WAITLIST)', is_reply=True)
draw_msg_a(1.6, 6.4, 3.8, '5. Cập nhật dữ liệu vào Riverpod state', is_reply=True)
draw_msg_a(1.0, 3.8, 1.2, '6. Thông báo kết quả tương ứng: Thành công hoặc Vào danh sách chờ', is_reply=True)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_13b_tuan_tu_dat_tien_ich.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 5. Sơ đồ trạng thái vòng đời hóa đơn & sự cố
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10.5, 5.5), dpi=220)
ax.axis('off')
ax.set_xlim(0, 10.5)
ax.set_ylim(0, 6.0)

ax.text(5.25, 5.6, 'SƠ ĐỒ TRẠNG THÁI VÒNG ĐỜI HÓA ĐƠN & PHIẾU PHẢN ÁNH SỰ CỐ', ha='center', va='center', fontsize=11.5, fontweight='bold', color='#1A365D')

# Left side: Invoice status
ax.text(2.6, 5.0, 'VÒNG ĐỜI HÓA ĐƠN DỊCH VỤ', ha='center', va='center', fontsize=9.5, fontweight='bold', color='#2B6CB0')
inv_states = [
    ('Chưa thanh toán\n(unpaid)', 2.6, 4.1, '#ED8936'),
    ('Đang chờ duyệt\n(pending_confirmation)', 2.6, 2.7, '#ECC94B'),
    ('Đã thanh toán\n(paid)', 2.6, 1.1, '#38A169')
]

for text, x, y, col in inv_states:
    box = patches.FancyBboxPatch((x-1.4, y-0.35), 2.8, 0.7, boxstyle='round,pad=0.15', facecolor='#FFFFFF', edgecolor=col, linewidth=2.0)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=8.5, fontweight='bold', color='#2D3748')

ax.annotate('Cư dân nộp ủy nhiệm chi', xy=(2.6, 3.05), xytext=(2.6, 3.75), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.2), ha='center', fontsize=7.5)
ax.annotate('Kế toán phê duyệt', xy=(2.6, 1.45), xytext=(2.6, 2.35), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.2), ha='center', fontsize=7.5)

# Direct cash payment curve
ax.annotate('Thu tiền mặt tại quầy / VietQR', xy=(1.2, 1.1), xytext=(1.2, 4.1), arrowprops=dict(arrowstyle='->', color='#38A169', lw=1.2, connectionstyle='arc3,rad=-0.4'), ha='right', va='center', fontsize=7.5, color='#276749')

# Right side: Issue status
ax.text(7.8, 5.0, 'VÒNG ĐỜI PHIẾU PHẢN ÁNH SỰ CỐ', ha='center', va='center', fontsize=9.5, fontweight='bold', color='#C53030')
issue_states = [
    ('Chờ tiếp nhận\n(pending)', 7.8, 4.1, '#E53E3E'),
    ('Đang xử lý\n(in_progress)', 7.8, 2.7, '#3182CE'),
    ('Đã hoàn thành\n(resolved)', 7.8, 1.1, '#38A169')
]

for text, x, y, col in issue_states:
    box = patches.FancyBboxPatch((x-1.4, y-0.35), 2.8, 0.7, boxstyle='round,pad=0.15', facecolor='#FFFFFF', edgecolor=col, linewidth=2.0)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=8.5, fontweight='bold', color='#2D3748')

ax.annotate('BQL phân công kỹ thuật viên', xy=(7.8, 3.05), xytext=(7.8, 3.75), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.2), ha='center', fontsize=7.5)
ax.annotate('KTV nghiệm thu & Sửa xong', xy=(7.8, 1.45), xytext=(7.8, 2.35), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.2), ha='center', fontsize=7.5)

# Rating note
ax.text(7.8, 0.35, 'Cư dân chấm điểm 1 - 5 sao và đánh giá chất lượng', ha='center', va='center', fontsize=7.8, fontstyle='italic', color='#718096')

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_14a_trang_thai_hoa_don.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 6. Biểu đồ Gantt tiến độ 6 tuần
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10, 4.8), dpi=220)
tasks = [
    'Giai đoạn 1: Khảo sát & Đặc tả yêu cầu',
    'Giai đoạn 2: Thiết kế kiến trúc & CSDL PostgreSQL',
    'Giai đoạn 3: Phát triển nền tảng, Auth & Khung giao diện',
    'Giai đoạn 4: Tích hợp nghiệp vụ Cư dân & Ban Quản Lý',
    'Giai đoạn 5: Rà soát bảo mật RLS, tối ưu RPC & Storage',
    'Giai đoạn 6: Kiểm thử tự động, nghiệm thu & Báo cáo'
]

starts = [1, 2, 3, 4, 5, 5]
durations = [2, 2, 2, 2, 1, 2]
colors = ['#3182CE', '#2B6CB0', '#38A169', '#D69E2E', '#E53E3E', '#805AD5']

y_pos = np.arange(len(tasks))
ax.barh(y_pos, durations, left=starts, height=0.55, align='center', color=colors, edgecolor='#2D3748', linewidth=1.0)
ax.set_yticks(y_pos)
ax.set_yticklabels(tasks, fontsize=9, fontweight='bold', color='#2D3748')
ax.invert_yaxis()
ax.set_xlabel('Tuần thực hiện dự án (1 - 6)', fontsize=10, fontweight='bold', color='#1A365D')
ax.set_xlim(0.8, 7.2)
ax.set_xticks(range(1, 8))
ax.set_xticklabels([f'Tuần {w}' for w in range(1, 8)], fontsize=9)
ax.grid(axis='x', linestyle='--', alpha=0.5)
ax.set_title('BIỂU ĐỒ GANTT TIẾN ĐỘ TRIỂN KHAI DỰ ÁN PKA-HOME', fontsize=11, fontweight='bold', color='#1A365D', pad=15)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh3_1_gantt_tien_do.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 7. Biểu đồ kết quả kiểm thử tự động 100% đạt
# -------------------------------------------------------------
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10.5, 4.5), dpi=220)

# Left: pie chart
labels = ['Vượt qua (Passed)\n395 bài kiểm thử\n(100%)']
sizes = [100]
colors_pie = ['#38A169']
wedges, texts = ax1.pie(sizes, labels=labels, colors=colors_pie, startangle=90, textprops=dict(fontsize=10, fontweight='bold', color='#1C4532'))
ax1.set_title('TỶ LỆ KIỂM THỬ THÀNH CÔNG\n(395/395 BÀI TEST)', fontsize=10.5, fontweight='bold', color='#1A365D')

# Right: bar chart of test categories
categories = [
    'Hằng số & Giao diện cơ sở',
    'Mô hình dữ liệu (Models)',
    'Kho lưu trữ (Repositories)',
    'Bộ điều phối (Providers)',
    'Màn hình Ban Quản Lý',
    'Màn hình Cư dân'
]
test_counts = [58, 74, 112, 65, 52, 34]
y_c = np.arange(len(categories))

ax2.barh(y_c, test_counts, height=0.55, color='#3182CE', edgecolor='#2B6CB0')
ax2.set_yticks(y_c)
ax2.set_yticklabels(categories, fontsize=8.5, fontweight='bold', color='#2D3748')
ax2.invert_yaxis()
ax2.set_xlabel('Số lượng bài kiểm thử tự động', fontsize=9, fontweight='bold', color='#1A365D')
ax2.grid(axis='x', linestyle='--', alpha=0.5)

for i, v in enumerate(test_counts):
    ax2.text(v + 1.5, i, f'{v} bài (100%)', va='center', fontsize=8, fontweight='bold', color='#2B6CB0')

ax2.set_xlim(0, 130)
ax2.set_title('PHÂN BỔ BÀI TEST THEO CÁC TẦNG HỆ THỐNG', fontsize=10.5, fontweight='bold', color='#1A365D')

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh_kiem_thu_tong_hop.png'), bbox_inches='tight')
plt.close()

print('ALL DIAGRAMS SUCCESSFULLY GENERATED!')
