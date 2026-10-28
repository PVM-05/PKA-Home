import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import os

plt.rcParams['font.sans-serif'] = ['Segoe UI', 'Arial', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False
out_dir = r'c:/Users/ADMIN/StudioProjects/pka_home/docs/report_assets'
os.makedirs(out_dir, exist_ok=True)

# -------------------------------------------------------------
# 1. Use Case Cư dân (Resident)
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10.8, 6.8), dpi=220)
ax.axis('off')
ax.set_xlim(0, 10.8)
ax.set_ylim(0, 8.4)

ax.text(5.4, 8.0, 'SƠ ĐỒ CA SỬ DỤNG - PHÂN HỆ CƯ DÂN (PKA-HOME)', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

# Actor box
actor_box = patches.FancyBboxPatch((0.4, 3.1), 1.8, 2.0, boxstyle='round,pad=0.2', facecolor='#EBF8FF', edgecolor='#3182CE', linewidth=2)
ax.add_patch(actor_box)
ax.text(1.3, 4.3, '[ ACTOR ]', fontsize=11, fontweight='bold', ha='center', va='center', color='#2B6CB0')
ax.text(1.3, 3.7, 'CƯ DÂN\n(RESIDENT)', fontsize=10, fontweight='bold', ha='center', va='center', color='#1A365D')

# Boundary
boundary = patches.Rectangle((2.8, 0.3), 7.6, 7.3, fill=False, edgecolor='#A0AEC0', linewidth=1.5, linestyle='--')
ax.add_patch(boundary)
ax.text(3.0, 7.35, 'Ranh giới hệ thống ứng dụng di động Cư dân', fontsize=9, fontstyle='italic', color='#718096')

use_cases = [
    'UC-R01: Đăng ký & Đăng nhập tài khoản bảo mật',
    'UC-R02: Gửi yêu cầu liên kết mã căn hộ (chuẩn A0110)',
    'UC-R03: Nhận thông báo tòa nhà (theo Toàn tòa, Block, Tầng, Phòng đích)',
    'UC-R04: Tra cứu hóa đơn dịch vụ & Chi tiết từng khoản phí (Generated Col)',
    'UC-R05: Thanh toán mô phỏng hai bước (VietQR, Chuyển khoản, Tiền mặt)',
    'UC-R06: Khai báo chỉ số công tơ điện nước & Chụp ảnh đồng hồ minh chứng',
    'UC-R07: Đặt lịch tiện ích, chọn số lượng người & Quản lý danh sách chờ',
    'UC-R08: Tự hủy lịch tiện ích an toàn (Atomic RPC hoàn cọc & đôn Waitlist)',
    'UC-R09: Đăng ký phương tiện cư dân (Theo dõi phê duyệt & Hủy thẻ xe)',
    'UC-R10: Gửi phản ánh sự cố kỹ thuật & Đính kèm ảnh minh chứng bảo mật',
    'UC-R11: Chấm điểm đánh giá chất lượng dịch vụ (1 - 5 sao 3 tiêu chí)',
    'UC-R12: Tra cứu cẩm nang cư dân, quy định tòa nhà & Danh bạ khẩn cấp'
]

y_positions = np.linspace(6.8, 0.6, len(use_cases))
for y, uc in zip(y_positions, use_cases):
    ellipse = patches.FancyBboxPatch((3.4, y-0.21), 6.7, 0.42, boxstyle='round,pad=0.15', facecolor='#F7FAFC', edgecolor='#4A5568', linewidth=1.2)
    ax.add_patch(ellipse)
    ax.text(6.75, y, uc, ha='center', va='center', fontsize=8.2, color='#2D3748', fontweight='bold')
    ax.annotate('', xy=(3.4, y), xytext=(2.2, 4.1), arrowprops=dict(arrowstyle='->', color='#3182CE', lw=1.2))

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_2a_use_case_cu_dan.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 2. Use Case Ban Quản Lý & Vận Hành (Management & Admin)
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11.2, 7.8), dpi=220)
ax.axis('off')
ax.set_xlim(0, 11.2)
ax.set_ylim(0, 8.8)

ax.text(5.6, 8.4, 'SƠ ĐỒ CA SỬ DỤNG - PHÂN HỆ BAN QUẢN LÝ & VẬN HÀNH', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

# Actors
actors = [
    ('BAN QUẢN LÝ', 6.5, '#2B6CB0', '#EBF8FF', '#3182CE'),
    ('KẾ TOÁN', 4.5, '#276749', '#F0FFF4', '#38A169'),
    ('KỸ THUẬT VIÊN', 2.5, '#C05621', '#FFFAF0', '#DD6B20'),
    ('QUẢN TRỊ VIÊN', 0.8, '#6B46C1', '#FAF5FF', '#805AD5')
]

for name, y, txt_col, bg_col, bdr_col in actors:
    box = patches.FancyBboxPatch((0.2, y-0.45), 1.9, 0.9, boxstyle='round,pad=0.15', facecolor=bg_col, edgecolor=bdr_col, linewidth=1.8)
    ax.add_patch(box)
    ax.text(1.15, y, name, ha='center', va='center', fontsize=8.5, fontweight='bold', color=txt_col)

# Boundary
boundary = patches.Rectangle((2.6, 0.2), 8.3, 7.9, fill=False, edgecolor='#A0AEC0', linewidth=1.5, linestyle='--')
ax.add_patch(boundary)
ax.text(2.8, 7.85, 'Ranh giới hệ thống Quản lý & Vận hành tòa nhà', fontsize=9, fontstyle='italic', color='#718096')

mgmt_cases = [
    ('UC-M01: Quản lý danh mục căn hộ (chuẩn A0110, diện tích, trạng thái)', [0, 3]),
    ('UC-M02: Phê duyệt / Từ chối yêu cầu liên kết căn hộ của cư dân', [0, 3]),
    ('UC-M03: Thẩm định ảnh công tơ & Duyệt chỉ số điện nước định kỳ', [1, 3]),
    ('UC-M04: Lập hóa đơn đơn lẻ & Phát hành hàng loạt an toàn (Preflight)', [1, 3]),
    ('UC-M05: Xác nhận thanh toán chuyển khoản & Thu tiền mặt tại quầy', [1, 3]),
    ('UC-M06: Phê duyệt / Từ chối đăng ký phương tiện & Biểu phí gửi xe', [0, 3]),
    ('UC-M07: Quản trị 3 Tab tiện ích: Duyệt lịch, Sửa sức chứa động, Lịch bảo trì', [0, 3]),
    ('UC-M08: Check-in điểm danh sử dụng tiện ích bằng mã đặt chỗ / QR', [0, 3]),
    ('UC-M09: Tiếp nhận sự cố kỹ thuật & Phân công kỹ thuật viên xử lý', [0, 2, 3]),
    ('UC-M10: Cập nhật tiến độ xử lý sự cố & Đính kèm minh chứng bảo mật', [2, 3]),
    ('UC-M11: Soạn thảo thông báo phân nhóm đích (Toàn tòa, Block, Tầng, Phòng)', [0, 3]),
    ('UC-M12: Quản lý thiết bị kỹ thuật tòa nhà & Cảnh báo bảo trì gián đoạn', [0, 2, 3]),
    ('UC-M13: Quản trị phân quyền RBAC, Ủy quyền vai trò & Nhật ký kiểm toán', [3])
]

y_mg = np.linspace(7.4, 0.5, len(mgmt_cases))
actor_y_map = {0: 6.5, 1: 4.5, 2: 2.5, 3: 0.8}
actor_colors = {0: '#3182CE', 1: '#38A169', 2: '#DD6B20', 3: '#805AD5'}

for y, (uc_title, act_idx_list) in zip(y_mg, mgmt_cases):
    ellipse = patches.FancyBboxPatch((3.2, y-0.21), 7.4, 0.42, boxstyle='round,pad=0.15', facecolor='#F7FAFC', edgecolor='#4A5568', linewidth=1.1)
    ax.add_patch(ellipse)
    ax.text(6.9, y, uc_title, ha='center', va='center', fontsize=8.2, color='#1A202C', fontweight='bold')
    
    for aidx in act_idx_list:
        ay = actor_y_map[aidx]
        col = actor_colors[aidx]
        ax.annotate('', xy=(3.2, y), xytext=(2.1, ay), arrowprops=dict(arrowstyle='->', color=col, lw=0.9, alpha=0.85))

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_2b_use_case_ban_quan_ly.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 3. Sơ đồ tuần tự: Thanh toán mô phỏng và đối soát hai bước
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 7.0), dpi=220)
ax.axis('off')
ax.set_xlim(0, 11)
ax.set_ylim(0, 7.6)

ax.text(5.5, 7.2, 'SƠ ĐỒ TUẦN TỰ: THANH TOÁN MÔ PHỎNG VÀ ĐỐI SOÁT HAI BƯỚC', ha='center', va='center', fontsize=12, fontweight='bold', color='#1A365D')

participants = [
    ('Cư dân', 1.0, '#3182CE'),
    ('Giao diện Flutter', 3.25, '#4A5568'),
    ('PaymentRepository', 5.5, '#4A5568'),
    ('PostgreSQL (RPC)', 7.75, '#C53030'),
    ('Kế toán / BQL', 10.0, '#276749')
]

for name, x, color in participants:
    box = patches.FancyBboxPatch((x-0.9, 6.3), 1.8, 0.6, boxstyle='round,pad=0.1', facecolor='#EDF2F7', edgecolor=color, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, 6.6, name, ha='center', va='center', fontsize=8.5, fontweight='bold', color=color)
    ax.plot([x, x], [0.5, 6.3], linestyle='--', color='#CBD5E0', linewidth=1.2)

def draw_msg(y, x1, x2, text, is_reply=False):
    style = '--' if is_reply else '-'
    col = '#718096' if is_reply else '#2B6CB0'
    ax.annotate('', xy=(x2, y), xytext=(x1, y), arrowprops=dict(arrowstyle='->', color=col, lw=1.2, linestyle=style))
    mid_x = (x1 + x2) / 2
    ax.text(mid_x, y+0.12, text, ha='center', va='bottom', fontsize=7.8, color='#1A202C', fontweight='medium')

draw_msg(5.9, 1.0, 3.25, '1. Chọn hóa đơn & Phương thức thanh toán (VietQR/Demo)')
draw_msg(5.5, 3.25, 5.5, '2. pay(type: INVOICE, refId, method, outcome)')
draw_msg(5.1, 5.5, 7.75, '3. Gọi RPC simulate_unified_payment(p_payment_type, p_reference_id...)')

# Active block on DB
db_block = patches.Rectangle((7.65, 3.8), 0.2, 1.3, facecolor='#FED7D7', edgecolor='#E53E3E')
ax.add_patch(db_block)
ax.text(8.8, 4.45, '[Xử lý máy chủ]\n- Khóa dòng FOR UPDATE\n- Kiểm tra quyền sở hữu RLS\n- Tạo giao dịch PENDING\n- Đổi hóa đơn: pending_confirmation', fontsize=7, color='#9B2C2C', ha='center', va='center', bbox=dict(boxstyle='square,pad=0.2', facecolor='#FFF5F5', edgecolor='#FEB2B2'))

draw_msg(3.6, 7.75, 5.5, '4. Trả về mã giao dịch và trạng thái PENDING', is_reply=True)
draw_msg(3.2, 5.5, 3.25, '5. Cập nhật trạng thái thành công', is_reply=True)
draw_msg(2.8, 3.25, 1.0, '6. Hiển thị: "Đang chờ kế toán xác nhận"', is_reply=True)

draw_msg(2.2, 10.0, 7.75, '7. Kế toán thẩm định chứng từ & Gọi RPC record_manual_payment')
draw_msg(1.6, 7.75, 10.0, '8. Đổi hóa đơn sang "paid" & Giao dịch sang "SUCCESS"', is_reply=True)
draw_msg(1.0, 7.75, 3.25, '9. Phát sự kiện Realtime cập nhật hóa đơn đã hoàn tất')
draw_msg(0.6, 3.25, 1.0, '10. Giao diện cư dân tự động chuyển sang thẻ xanh "Đã thanh toán"', is_reply=True)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_13a_tuan_tu_thanh_toan.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 4. Sơ đồ tuần tự: Đặt tiện ích, Kiểm soát sức chứa & Hủy lịch an toàn
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 7.2), dpi=220)
ax.axis('off')
ax.set_xlim(0, 11)
ax.set_ylim(0, 7.8)

ax.text(5.5, 7.4, 'SƠ ĐỒ TUẦN TỰ: ĐẶT TIỆN ÍCH, KIỂM SOÁT SỨC CHỨA & HỦY LỊCH AN TOÀN', ha='center', va='center', fontsize=11.5, fontweight='bold', color='#1A365D')

parts_amenity = [
    ('Cư dân', 1.1, '#3182CE'),
    ('Giao diện Flutter', 3.6, '#4A5568'),
    ('AmenityRepository', 6.2, '#4A5568'),
    ('PostgreSQL (RPCs)', 8.8, '#C53030'),
    ('Ban Quản Lý', 10.4, '#276749')
]

for name, x, color in parts_amenity:
    box = patches.FancyBboxPatch((x-0.85, 6.5), 1.7, 0.6, boxstyle='round,pad=0.1', facecolor='#EDF2F7', edgecolor=color, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, 6.8, name, ha='center', va='center', fontsize=8.2, fontweight='bold', color=color)
    ax.plot([x, x], [0.5, 6.5], linestyle='--', color='#CBD5E0', linewidth=1.2)

def draw_msg_b(y, x1, x2, text, is_reply=False):
    style = '--' if is_reply else '-'
    col = '#718096' if is_reply else '#2B6CB0'
    ax.annotate('', xy=(x2, y), xytext=(x1, y), arrowprops=dict(arrowstyle='->', color=col, lw=1.2, linestyle=style))
    mid_x = (x1 + x2) / 2
    ax.text(mid_x, y+0.11, text, ha='center', va='bottom', fontsize=7.6, color='#1A202C', fontweight='medium')

draw_msg_b(6.1, 1.1, 3.6, '1. Chọn ngày, slot giờ, số lượng khách (guests_count)')
draw_msg_b(5.7, 3.6, 6.2, '2. bookSlot(amenityId, date, slot, guests)')
draw_msg_b(5.3, 6.2, 8.8, '3. Gọi RPC book_amenity_slot(...)')

# DB lock block
db_b2 = patches.Rectangle((8.7, 3.8), 0.2, 1.5, facecolor='#FED7D7', edgecolor='#E53E3E')
ax.add_patch(db_b2)
ax.text(7.3, 4.5, '[Xử lý giao dịch máy chủ]\n1. Khóa tài nguyên ngày/giờ FOR UPDATE\n2. Đếm tổng số người các booking hiện tại\n3. booked_count + guests <= max_capacity?\n4. Nếu còn: Ghi nhận CONFIRMED\n5. Nếu hết: Ghi nhận WAITLIST danh sách chờ', fontsize=6.8, color='#9B2C2C', ha='center', va='center', bbox=dict(boxstyle='square,pad=0.2', facecolor='#FFF5F5', edgecolor='#FEB2B2'))

draw_msg_b(3.5, 8.8, 6.2, '4. Trả về mã đặt chỗ & Trạng thái (CONFIRMED / WAITLIST)', is_reply=True)
draw_msg_b(3.1, 6.2, 3.6, '5. Cập nhật state & Hiển thị huy hiệu "Lịch của bạn"', is_reply=True)

# Cancellation & Waitlist promotion
draw_msg_b(2.4, 1.1, 3.6, '6. Cư dân bấm nút [Hủy lịch này] (nút tự xuống dòng Wrap)')
draw_msg_b(2.0, 3.6, 6.2, '7. cancelBooking(bookingId)')
draw_msg_b(1.6, 6.2, 8.8, '8. Gọi RPC cancel_amenity_booking(p_booking_id)')
draw_msg_b(1.1, 8.8, 10.4, '9. Tự động hủy giao dịch, hoàn cọc & Đôn người từ Waitlist lên')
draw_msg_b(0.7, 8.8, 3.6, '10. Cập nhật thành công, mở lại chỗ trống cho cư dân khác', is_reply=True)

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_13b_tuan_tu_dat_tien_ich.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 5. Sơ đồ trạng thái vòng đời: Hóa đơn, Tiện ích & Sự cố
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11.0, 6.2), dpi=220)
ax.axis('off')
ax.set_xlim(0, 11.0)
ax.set_ylim(0, 6.5)

ax.text(5.5, 6.2, 'SƠ ĐỒ TRẠNG THÁI VÒNG ĐỜI: HÓA ĐƠN, ĐẶT TIỆN ÍCH & SỰ CỐ KỸ THUẬT', ha='center', va='center', fontsize=11.5, fontweight='bold', color='#1A365D')

# 1. Left side: Invoice status
ax.text(1.8, 5.6, 'HÓA ĐƠN DỊCH VỤ', ha='center', va='center', fontsize=9.2, fontweight='bold', color='#2B6CB0')
inv_states = [
    ('Chưa thanh toán\n(unpaid)', 1.8, 4.6, '#ED8936'),
    ('Chờ BQL duyệt\n(pending_confirmation)', 1.8, 3.0, '#ECC94B'),
    ('Đã thanh toán\n(paid)', 1.8, 1.2, '#38A169')
]
for text, x, y, col in inv_states:
    box = patches.FancyBboxPatch((x-1.15, y-0.35), 2.3, 0.7, boxstyle='round,pad=0.15', facecolor='#FFFFFF', edgecolor=col, linewidth=1.8)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=7.8, fontweight='bold', color='#2D3748')

ax.annotate('Cư dân thanh toán\nVietQR / Demo', xy=(1.8, 3.35), xytext=(1.8, 4.25), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.1), ha='center', fontsize=7)
ax.annotate('Kế toán đối soát\n& duyệt thanh toán', xy=(1.8, 1.55), xytext=(1.8, 2.65), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.1), ha='center', fontsize=7)
ax.annotate('Thu tiền mặt tại quầy', xy=(0.65, 1.2), xytext=(0.65, 4.6), arrowprops=dict(arrowstyle='->', color='#38A169', lw=1.1, connectionstyle='arc3,rad=-0.4'), ha='right', va='center', fontsize=7, color='#276749')

# 2. Middle side: Amenity booking status
ax.text(5.5, 5.6, 'ĐẶT LỊCH TIỆN ÍCH', ha='center', va='center', fontsize=9.2, fontweight='bold', color='#6B46C1')
amenity_states = [
    ('Chờ thanh toán\n(pending_payment)', 4.3, 4.6, '#DD6B20'),
    ('Danh sách chờ\n(waitlist)', 6.7, 4.6, '#805AD5'),
    ('Đã xác nhận\n(confirmed)', 5.5, 3.0, '#3182CE'),
    ('Đã Check-in / Hoàn tất\n(completed)', 4.3, 1.2, '#38A169'),
    ('Đã hủy lịch\n(cancelled)', 6.7, 1.2, '#E53E3E')
]
for text, x, y, col in amenity_states:
    box = patches.FancyBboxPatch((x-1.05, y-0.35), 2.1, 0.7, boxstyle='round,pad=0.12', facecolor='#FFFFFF', edgecolor=col, linewidth=1.8)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=7.6, fontweight='bold', color='#2D3748')

ax.annotate('Đóng phí / cọc', xy=(5.0, 3.35), xytext=(4.3, 4.25), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.0), ha='center', fontsize=6.8)
ax.annotate('Đôn slot khi có hủy', xy=(5.9, 3.35), xytext=(6.7, 4.25), arrowprops=dict(arrowstyle='->', color='#805AD5', lw=1.0), ha='center', fontsize=6.8)
ax.annotate('BQL điểm danh', xy=(4.3, 1.55), xytext=(5.1, 2.65), arrowprops=dict(arrowstyle='->', color='#38A169', lw=1.0), ha='center', fontsize=6.8)
ax.annotate('Cư dân tự hủy\nRPC an toàn', xy=(6.7, 1.55), xytext=(5.9, 2.65), arrowprops=dict(arrowstyle='->', color='#E53E3E', lw=1.0), ha='center', fontsize=6.8)

# 3. Right side: Issue report status
ax.text(9.2, 5.6, 'PHẢN ÁNH SỰ CỐ', ha='center', va='center', fontsize=9.2, fontweight='bold', color='#C53030')
issue_states = [
    ('Chờ tiếp nhận\n(pending)', 9.2, 4.6, '#E53E3E'),
    ('Đang xử lý\n(in_progress)', 9.2, 3.0, '#3182CE'),
    ('Đã hoàn thành\n(resolved)', 9.2, 1.2, '#38A169')
]
for text, x, y, col in issue_states:
    box = patches.FancyBboxPatch((x-1.15, y-0.35), 2.3, 0.7, boxstyle='round,pad=0.15', facecolor='#FFFFFF', edgecolor=col, linewidth=1.8)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=7.8, fontweight='bold', color='#2D3748')

ax.annotate('BQL phân công KTV', xy=(9.2, 3.35), xytext=(9.2, 4.25), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.1), ha='center', fontsize=7)
ax.annotate('KTV sửa & gửi ảnh', xy=(9.2, 1.55), xytext=(9.2, 2.65), arrowprops=dict(arrowstyle='->', color='#4A5568', lw=1.1), ha='center', fontsize=7)
ax.text(9.2, 0.45, 'Cư dân chấm điểm 1 - 5 sao', ha='center', va='center', fontsize=7.2, fontstyle='italic', color='#718096')

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_14a_trang_thai_hoa_don.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 6. Biểu đồ Gantt tiến độ 6 tuần
# -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(10, 4.8), dpi=220)
tasks = [
    'Giai đoạn 1: Khảo sát, Đặc tả yêu cầu & Thiết kế CSDL',
    'Giai đoạn 2: Phát triển Core, Theme, Auth & RBAC',
    'Giai đoạn 3: Nghiệp vụ Hóa đơn, Điện nước & Thanh toán mô phỏng',
    'Giai đoạn 4: Phân hệ Tiện ích 3 Tab, Sức chứa động & Phương tiện',
    'Giai đoạn 5: Thông báo phân nhóm đích, Sự cố kỹ thuật & Đánh giá sao',
    'Giai đoạn 6: Rà soát bảo mật RLS, Kiểm thử tự động 100% & Báo cáo'
]

starts = [1, 2, 3, 4, 4.5, 5]
durations = [2, 1.5, 1.8, 1.8, 1.5, 1.5]
colors = ['#3182CE', '#2B6CB0', '#38A169', '#D69E2E', '#E53E3E', '#805AD5']

y_pos = np.arange(len(tasks))
ax.barh(y_pos, durations, left=starts, height=0.55, align='center', color=colors, edgecolor='#2D3748', linewidth=1.0)
ax.set_yticks(y_pos)
ax.set_yticklabels(tasks, fontsize=8.8, fontweight='bold', color='#2D3748')
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
# 7. Biểu đồ kết quả kiểm thử tự động (408 Tests - 100% Logic Pass)
# -------------------------------------------------------------
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10.8, 4.6), dpi=220)

# Left: pie chart
labels = ['Đạt (Passed)\n405 bài test\n(100% Unit/Widget/UI)', 'Bỏ qua (Skipped)\n3 bài RLS Cloud']
sizes = [405, 3]
colors_pie = ['#38A169', '#CBD5E0']
wedges, texts, autotexts = ax1.pie(sizes, labels=labels, autopct='%1.1f%%', colors=colors_pie, startangle=80, textprops=dict(fontsize=9, fontweight='bold', color='#1C4532'))
ax1.set_title('TỶ LỆ KIỂM THỬ THÀNH CÔNG\n(405/405 BÀI TEST CHỨC NĂNG ĐẠT)', fontsize=10.5, fontweight='bold', color='#1A365D')

# Right: bar chart of test categories
categories = [
    'Hằng số & Giao diện cơ sở',
    'Mô hình dữ liệu (Models)',
    'Kho lưu trữ & Dịch vụ (Repos/Services)',
    'Bộ điều phối (Providers)',
    'Màn hình Ban Quản Lý (3 Tab & Preflight)',
    'Màn hình Cư dân & Responsive 360dp'
]
test_counts = [62, 78, 116, 68, 54, 30]
y_c = np.arange(len(categories))

ax2.barh(y_c, test_counts, height=0.55, color='#3182CE', edgecolor='#2B6CB0')
ax2.set_yticks(y_c)
ax2.set_yticklabels(categories, fontsize=8.5, fontweight='bold', color='#2D3748')
ax2.invert_yaxis()
ax2.set_xlabel('Số lượng bài kiểm thử tự động', fontsize=9, fontweight='bold', color='#1A365D')
ax2.grid(axis='x', linestyle='--', alpha=0.5)

for i, v in enumerate(test_counts):
    ax2.text(v + 1.5, i, f'{v} bài (100%)', va='center', fontsize=8, fontweight='bold', color='#2B6CB0')

ax2.set_xlim(0, 135)
ax2.set_title('PHÂN BỔ BÀI TEST THEO CÁC TẦNG HỆ THỐNG', fontsize=10.5, fontweight='bold', color='#1A365D')

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh_kiem_thu_tong_hop.png'), bbox_inches='tight')
plt.close()

# -------------------------------------------------------------
# 8. Sơ đồ kiến trúc Quản trị Tiện ích 3 Tab & Thông báo phân nhóm đích (MỚI)
# -------------------------------------------------------------
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11.2, 5.4), dpi=220)

# Left: 3-Tab Amenity Architecture
ax1.axis('off')
ax1.set_xlim(0, 5.5)
ax1.set_ylim(0, 6.0)
ax1.text(2.75, 5.7, 'KIẾN TRÚC QUẢN TRỊ TIỆN ÍCH 3 TAB (BQL)', ha='center', va='center', fontsize=10, fontweight='bold', color='#1A365D')

tabs = [
    ('Tab 1: Duyệt Lịch Đặt Chỗ (Chuẩn A7/A8)', 4.7, '#2B6CB0', '#EBF8FF', [
        '• Tìm kiếm căn hộ (A0110), người đặt & Lọc trạng thái',
        '• Nút Duyệt, Từ chối kèm lý do & Thu phí/cọc tại quầy',
        '• Nút Check-in điểm danh & Quét mã QR trên AppBar'
    ]),
    ('Tab 2: Cấu Hình Tiện Ích & Sức Chứa Động', 2.9, '#276749', '#F0FFF4', [
        '• Danh sách tiện ích: Bể bơi (30), Gym (20), BBQ (15)',
        '• Sửa sức chứa động (max_capacity) theo thực tế',
        '• Cấu hình hình thức: Dùng chung / Bao trọn khung giờ'
    ]),
    ('Tab 3: Lịch Bảo Trì & Gián Đoạn Dịch Vụ', 1.1, '#C05621', '#FFFAF0', [
        '• Bộ chọn tiện ích độc lập và lịch ngày cụ thể',
        '• Thêm khung giờ bảo dưỡng / vệ sinh kỹ thuật',
        '• Tự động đóng slot đặt chỗ ngăn cư dân đặt trùng'
    ])
]

for title, y, bdr, bg, bullets in tabs:
    box = patches.FancyBboxPatch((0.2, y-0.75), 5.1, 1.45, boxstyle='round,pad=0.15', facecolor=bg, edgecolor=bdr, linewidth=1.5)
    ax1.add_patch(box)
    ax1.text(0.4, y+0.45, title, fontsize=8.2, fontweight='bold', color=bdr)
    for idx, b in enumerate(bullets):
        ax1.text(0.4, y+0.12 - idx*0.28, b, fontsize=7.2, color='#2D3748')

# Right: Targeted Announcement Architecture
ax2.axis('off')
ax2.set_xlim(0, 5.5)
ax2.set_ylim(0, 6.0)
ax2.text(2.75, 5.7, 'CƠ CHẾ PHÂN NHÓM ĐÍCH THÔNG BÁO TÒA NHÀ', ha='center', va='center', fontsize=10, fontweight='bold', color='#1A365D')

targets = [
    ('1. Toàn Tòa Nhà (target_type = ALL)', 4.7, '#2B6CB0', '#EBF8FF', 'Áp dụng cho thông báo chung, lịch cúp điện toàn khu'),
    ('2. Theo Tòa / Block (target_type = BUILDING)', 3.5, '#3182CE', '#EBF8FF', 'Gửi cư dân Tòa A, B hoặc C (VD: bảo trì thang máy tháp A)'),
    ('3. Theo Tầng (target_type = FLOOR)', 2.3, '#D69E2E', '#FEFCBF', 'Gửi các căn hộ cùng tầng (VD: vệ sinh hành lang tầng 5)'),
    ('4. Căn Hộ Cụ Thể (target_type = APARTMENT)', 1.1, '#E53E3E', '#FED7D7', 'Thông báo nhắc nợ riêng, sự cố nội bộ căn hộ (A0110)')
]

for title, y, bdr, bg, desc in targets:
    box = patches.FancyBboxPatch((0.2, y-0.45), 5.1, 0.9, boxstyle='round,pad=0.12', facecolor=bg, edgecolor=bdr, linewidth=1.4)
    ax2.add_patch(box)
    ax2.text(0.4, y+0.15, title, fontsize=8.0, fontweight='bold', color=bdr)
    ax2.text(0.4, y-0.2, desc, fontsize=7.2, color='#2D3748')

plt.tight_layout()
plt.savefig(os.path.join(out_dir, 'hinh2_15_kien_truc_tien_ich_va_thong_bao.png'), bbox_inches='tight')
plt.close()

print('ALL 8 DIAGRAMS SUCCESSFULLY GENERATED IN REPORT_ASSETS!')
