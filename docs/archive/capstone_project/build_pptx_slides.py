import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

def create_presentation():
    prs = Presentation()
    # 16:9 Widescreen: 13.333 x 7.5 inches
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    
    blank_layout = prs.slide_layouts[6] # completely blank layout

    assets_dir = r'c:/Users/ADMIN/StudioProjects/pka_home/docs/report_assets'

    # Color Palette
    C_NAVY = RGBColor(26, 54, 93)      # #1A365D Primary
    C_BLUE = RGBColor(49, 130, 206)    # #3182CE Accent
    C_ORANGE = RGBColor(221, 107, 32)  # #DD6B20 Warning / Highlight
    C_GREEN = RGBColor(56, 161, 105)   # #38A169 Success
    C_DARK = RGBColor(45, 55, 72)      # #2D3748 Text Dark
    C_MUTED = RGBColor(113, 128, 150)  # #718096 Secondary
    C_BG = RGBColor(248, 250, 252)     # #F8FAFC Slide Background
    C_WHITE = RGBColor(255, 255, 255)
    C_CARD_BG = RGBColor(255, 255, 255)
    C_BORDER = RGBColor(226, 232, 240)

    def add_header(slide, title_text, category="ĐỒ ÁN LIÊN NGÀNH - TRƯỜNG CÔNG NGHỆ THÔNG TIN"):
        # Header background banner
        top_bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(1.15))
        top_bar.fill.solid()
        top_bar.fill.fore_color.rgb = C_NAVY
        top_bar.line.fill.background()
        
        # Category sub-label
        tx_cat = slide.shapes.add_textbox(Inches(0.8), Inches(0.12), Inches(10), Inches(0.3))
        tf_c = tx_cat.text_frame
        tf_c.word_wrap = True
        p_c = tf_c.paragraphs[0]
        p_c.text = category.upper()
        p_c.font.name = "Segoe UI"
        p_c.font.size = Pt(9.5)
        p_c.font.bold = True
        p_c.font.color.rgb = C_BLUE

        # Main Slide Title
        tx_title = slide.shapes.add_textbox(Inches(0.8), Inches(0.42), Inches(11.5), Inches(0.65))
        tf_t = tx_title.text_frame
        tf_t.word_wrap = True
        p_t = tf_t.paragraphs[0]
        p_t.text = title_text
        p_t.font.name = "Segoe UI"
        p_t.font.size = Pt(22)
        p_t.font.bold = True
        p_t.font.color.rgb = C_WHITE

        # Bottom accent line
        line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(1.15), Inches(13.333), Inches(0.05))
        line.fill.solid()
        line.fill.fore_color.rgb = C_ORANGE
        line.line.fill.background()

    def set_notes(slide, notes_text):
        notes_slide = slide.notes_slide
        tf = notes_slide.notes_text_frame
        tf.text = notes_text

    def add_card(slide, left, top, width, height, title=None, bg_color=C_CARD_BG, border_color=C_BORDER):
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        card.fill.solid()
        card.fill.fore_color.rgb = bg_color
        card.line.color.rgb = border_color
        card.line.width = Pt(1.5)
        
        if title:
            tb = slide.shapes.add_textbox(left + Inches(0.15), top + Inches(0.12), width - Inches(0.3), Inches(0.45))
            tf = tb.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            p.text = title
            p.font.name = "Segoe UI"
            p.font.size = Pt(13)
            p.font.bold = True
            p.font.color.rgb = C_NAVY
        return card

    # =========================================================
    # SLIDE 1: TRANG BÌA (COVER SLIDE)
    # =========================================================
    s1 = prs.slides.add_slide(blank_layout)
    # Background full
    bg1 = s1.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(7.5))
    bg1.fill.solid()
    bg1.fill.fore_color.rgb = C_NAVY
    bg1.line.fill.background()

    # Logo Phenikaa
    logo_path = os.path.join(assets_dir, 'image1.png')
    if os.path.exists(logo_path):
        s1.shapes.add_picture(logo_path, Inches(1.2), Inches(1.8), height=Inches(3.8))

    # Right Content Box
    tx1 = s1.shapes.add_textbox(Inches(4.8), Inches(1.2), Inches(7.8), Inches(5.2))
    tf1 = tx1.text_frame
    tf1.word_wrap = True
    
    p1 = tf1.paragraphs[0]
    p1.text = "TRƯỜNG ĐẠI HỌC PHENIKAA\nTRƯỜNG CÔNG NGHỆ THÔNG TIN"
    p1.font.name = "Segoe UI"
    p1.font.size = Pt(15)
    p1.font.bold = True
    p1.font.color.rgb = C_BLUE

    p2 = tf1.add_paragraph()
    p2.text = "\nBÁO CÁO ĐỒ ÁN LIÊN NGÀNH"
    p2.font.name = "Segoe UI"
    p2.font.size = Pt(20)
    p2.font.bold = True
    p2.font.color.rgb = C_ORANGE

    p3 = tf1.add_paragraph()
    p3.text = "ỨNG DỤNG QUẢN LÝ CHUNG CƯ\n(PKA-HOME)"
    p3.font.name = "Segoe UI"
    p3.font.size = Pt(30)
    p3.font.bold = True
    p3.font.color.rgb = C_WHITE

    p4 = tf1.add_paragraph()
    p4.text = (
        "\nSinh viên thực hiện: Phạm Văn Minh\n"
        "Mã sinh viên: 23010350\n"
        "Email: 23010350@st.phenikaa-uni.edu.vn\n\n"
        "Giảng viên hướng dẫn: Tiến sĩ Nguyễn Thị Vân\n"
        "Thời gian: Hà Nội, tháng 10 năm 2026"
    )
    p4.font.name = "Segoe UI"
    p4.font.size = Pt(13)
    p4.font.color.rgb = RGBColor(226, 232, 240)

    set_notes(s1, "Kính thưa quý thầy cô trong Hội đồng đánh giá đồ án liên ngành! Em tên là Phạm Văn Minh, sinh viên khóa 2023 ngành Công nghệ Thông tin. Hôm nay, em xin phép được báo cáo kết quả nghiên cứu và hiện thực hóa đề tài: 'Ứng dụng Quản lý Chung cư PKA-Home' dưới sự hướng dẫn khoa học của Tiến sĩ Nguyễn Thị Vân. Kính mời quý thầy cô cùng theo dõi nội dung báo cáo.")

    # =========================================================
    # SLIDE 2: NỘI DUNG BÁO CÁO (AGENDA)
    # =========================================================
    s2 = prs.slides.add_slide(blank_layout)
    add_header(s2, "NỘI DUNG BÁO CÁO ĐỒ ÁN (AGENDA)")

    agenda_items = [
        ("01", "ĐẶT VẤN ĐỀ & MỤC TIÊU", "Thực trạng vận hành chung cư, mục tiêu và phạm vi đề tài"),
        ("02", "KHẢO SÁT & GIẢI PHÁP ĐỀ XUẤT", "So sánh các phương thức quản lý và giá trị mới của PKA-Home"),
        ("03", "PHÂN TÍCH YÊU CẦU & THIẾT KẾ", "Mô hình tác nhân, 23 ca sử dụng và đặc tả chi tiết nghiệp vụ"),
        ("04", "KIẾN TRÚC PHẦN MỀM & CSDL", "Kiến trúc Feature-first, 16 bảng CSDL quan hệ và RPC máy chủ"),
        ("05", "ĐIỂM SÁNG KỸ THUẬT & TOÀN VẸN", "Phòng thủ 3 lớp, bảo toàn tài chính CSDL, khóa sức chứa tiện ích"),
        ("06", "KẾT QUẢ TRIỂN KHAI & GIAO DIỆN", "Minh chứng ứng dụng thực tế phân hệ Cư dân và Ban Quản Lý"),
        ("07", "KIỂM THỬ TỰ ĐỘNG & NGHIỆM THU", "131 tệp kiểm thử, 395 ca test vượt qua 100%, phân tích tĩnh sạch"),
        ("08", "KẾT LUẬN & HƯỚNG PHÁT TRIỂN", "Đánh giá kết quả đạt được và định hướng nâng cấp trong tương lai")
    ]

    for idx, (num, title, desc) in enumerate(agenda_items):
        col = idx % 2
        row = idx // 2
        l = Inches(0.8 + col * 5.9)
        t = Inches(1.5 + row * 1.35)
        
        c = add_card(s2, l, t, Inches(5.6), Inches(1.15))
        
        # Number badge
        badge = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, l + Inches(0.2), t + Inches(0.2), Inches(0.75), Inches(0.75))
        badge.fill.solid()
        badge.fill.fore_color.rgb = C_BLUE
        badge.line.fill.background()
        p_b = badge.text_frame.paragraphs[0]
        p_b.text = num
        p_b.font.name = "Segoe UI"
        p_b.font.size = Pt(16)
        p_b.font.bold = True
        p_b.font.color.rgb = C_WHITE
        p_b.alignment = PP_ALIGN.CENTER
        
        # Text
        tx = s2.shapes.add_textbox(l + Inches(1.1), t + Inches(0.15), Inches(4.3), Inches(0.85))
        tf = tx.text_frame
        tf.word_wrap = True
        p_t = tf.paragraphs[0]
        p_t.text = title
        p_t.font.name = "Segoe UI"
        p_t.font.size = Pt(12)
        p_t.font.bold = True
        p_t.font.color.rgb = C_NAVY
        
        p_d = tf.add_paragraph()
        p_d.text = desc
        p_d.font.name = "Segoe UI"
        p_d.font.size = Pt(9.5)
        p_d.font.color.rgb = C_MUTED

    set_notes(s2, "Nội dung báo cáo của em ngày hôm nay gồm tám phần trọng tâm, đi từ bài toán thực tế, phân tích thiết kế, các giải pháp kỹ thuật bảo đảm an toàn dữ liệu, đến kết quả nghiệm thu kiểm thử tự động trên hệ thống và kế hoạch mở rộng trong tương lai.")

    # =========================================================
    # SLIDE 3: ĐẶT VẤN ĐỀ & BÀI TOÁN QUẢN LÝ
    # =========================================================
    s3 = prs.slides.add_slide(blank_layout)
    add_header(s3, "ĐẶT VẤN ĐỀ & THỰC TRẠNG QUẢN TRỊ TÒA NHÀ")

    # 4 Issue Cards
    issues = [
        ("DỮ LIỆU PHÂN TÁN", "Ghi chép thủ công trên giấy tờ và nhiều tệp bảng tính rời rạc. Thông báo gửi qua mạng xã hội dễ bị trôi tin, thất lạc lịch sử trao đổi.", C_ORANGE),
        ("SAI LỆCH TÀI CHÍNH", "Thu thập chỉ số điện nước và tính tiền thủ công dễ dẫn đến sai sót số đo, nhầm lẫn đơn giá hoặc phát hành trùng lặp hóa đơn trong cùng kỳ.", C_ORANGE),
        ("THIẾU MINH BẠCH & TỨC THỜI", "Cư dân không theo dõi được tiến độ khắc phục sự cố hư hỏng hạ tầng; Ban Quản Lý gặp khó khăn trong việc điều phối nhân sự kỹ thuật.", C_NAVY),
        ("RỦI RO BẢO MẬT THÔNG TIN", "Thiếu cơ chế phân quyền bảo mật cấp dữ liệu, thông tin cá nhân và số điện thoại của cư dân có thể bị truy cập trái phép.", C_NAVY)
    ]

    for idx, (title, desc, color) in enumerate(issues):
        col = idx % 2
        row = idx // 2
        l = Inches(0.8 + col * 5.9)
        t = Inches(1.5 + row * 2.6)
        
        add_card(s3, l, t, Inches(5.6), Inches(2.3), title=title, border_color=color)
        
        tx = s3.shapes.add_textbox(l + Inches(0.2), t + Inches(0.65), Inches(5.2), Inches(1.5))
        tf = tx.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = desc
        p.font.name = "Segoe UI"
        p.font.size = Pt(12)
        p.font.color.rgb = C_DARK
        p.line_spacing = 1.3

    set_notes(s3, "Hiện nay, việc quản trị chung cư thường gặp khó khăn do dữ liệu phân tán trên nhiều kênh như sổ sách, bảng tính và nhóm mạng xã hội. Điều này dẫn đến nguy cơ sai lệch số liệu tài chính khi chốt chỉ số điện nước, cư dân không theo dõi được tiến độ sửa chữa hạ tầng, và thông tin cư trú chưa được bảo vệ an toàn.")

    # =========================================================
    # SLIDE 4: MỤC TIÊU & PHẠM VI NGHIÊN CỨU
    # =========================================================
    s4 = prs.slides.add_slide(blank_layout)
    add_header(s4, "MỤC TIÊU VÀ PHẠM VI NGHIÊN CỨU")

    # Left: Goals
    add_card(s4, Inches(0.8), Inches(1.5), Inches(5.6), Inches(5.4), title="MỤC TIÊU ĐỀ TÀI", border_color=C_BLUE)
    tx_g = s4.shapes.add_textbox(Inches(1.0), Inches(2.2), Inches(5.2), Inches(4.5))
    tf_g = tx_g.text_frame
    tf_g.word_wrap = True
    
    goals = [
        "Xây dựng ứng dụng di động hoàn chỉnh bằng Flutter với 100% giao diện tiếng Việt chuẩn mực.",
        "Thiết kế cơ sở dữ liệu quan hệ đồng nhất trên PostgreSQL (Supabase), chuẩn hóa mã căn hộ A0110.",
        "Thiết lập cơ chế phòng thủ ba lớp chống leo thang đặc quyền và bảo đảm toàn vẹn tài chính cấp máy chủ.",
        "Hiện thực hóa quy trình nghiệp vụ tự động: lập hóa đơn hàng loạt, duyệt chỉ số, quản lý sức chứa tiện ích.",
        "Xây dựng bộ kiểm thử tự động toàn diện kiểm chứng độ tin cậy của phần mềm trước khi nghiệm thu."
    ]
    for g in goals:
        p = tf_g.add_paragraph() if tf_g.paragraphs[0].text else tf_g.paragraphs[0]
        p.text = f"• {g}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(11.5)
        p.font.color.rgb = C_DARK
        p.line_spacing = 1.25

    # Right: Scope
    add_card(s4, Inches(6.8), Inches(1.5), Inches(5.7), Inches(5.4), title="PHẠM VI THỰC HIỆN", border_color=C_ORANGE)
    tx_s = s4.shapes.add_textbox(Inches(7.0), Inches(2.2), Inches(5.3), Inches(4.5))
    tf_s = tx_s.text_frame
    tf_s.word_wrap = True

    scopes = [
        "Nền tảng mục tiêu: Tập trung phát triển và tối ưu hóa trải nghiệm trên thiết bị di động Android phục vụ bảo vệ đồ án.",
        "Quy trình tài chính: Cung cấp cổng thanh toán mô phỏng khép kín (VietQR mô phỏng, nộp ủy nhiệm chi xác nhận 2 bước, thu tiền mặt tại quầy), không chuyển tiền ngân hàng thật.",
        "Chỉ số điện nước: Bao gồm chức năng nộp chỉ số kèm ảnh chụp công tơ thực tế và thẩm định số đo của kế toán.",
        "Môi trường kiểm thử: Sử dụng bộ tài khoản dữ liệu mẫu đã được nạp sẵn và đồng bộ an toàn trên Supabase."
    ]
    for sc in scopes:
        p = tf_s.add_paragraph() if tf_s.paragraphs[0].text else tf_s.paragraphs[0]
        p.text = f"• {sc}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(11.5)
        p.font.color.rgb = C_DARK
        p.line_spacing = 1.25

    set_notes(s4, "Mục tiêu trọng tâm của đề tài là xây dựng một nền tảng chuyển đổi số toàn diện, kết nối cư dân với ban quản lý, đồng thời giải quyết triệt để vấn đề toàn vẹn dữ liệu tài chính bằng cách chuyển toàn bộ tính toán nhạy cảm về phía máy chủ thay vì tin cậy ứng dụng khách.")

    # =========================================================
    # SLIDE 5: ĐỐI TƯỢNG SỬ DỤNG & PHÂN QUYỀN
    # =========================================================
    s5 = prs.slides.add_slide(blank_layout)
    add_header(s5, "MÔ HÌNH PHÂN QUYỀN ĐA VAI TRÒ (ENTERPRISE RBAC)")

    roles = [
        ("CƯ DÂN (RESIDENT)", "Xem hóa đơn căn hộ mình, thanh toán mô phỏng, gửi phản ánh sự cố, đặt tiện ích, đăng ký xe máy, ô tô.", C_BLUE),
        ("BAN QUẢN LÝ (MANAGEMENT)", "Quản lý căn hộ, phê duyệt liên kết, điều phối sự cố, duyệt phương tiện, phát thông báo diện rộng.", C_NAVY),
        ("KẾ TOÁN (ACCOUNTANT)", "Thẩm định chỉ số điện nước, lập hóa đơn đơn lẻ & hàng loạt, xác nhận thanh toán, thu tiền mặt tại quầy.", C_GREEN),
        ("KỸ THUẬT VIÊN (TECHNICIAN)", "Tiếp nhận phiếu sự cố được giao, cập nhật tiến độ, ảnh chụp nghiệm thu sửa chữa và trao đổi với cư dân.", C_ORANGE),
        ("QUẢN TRỊ VIÊN (ADMIN)", "Toàn quyền quản trị cấu hình hệ thống, phân quyền vai trò, ủy quyền nhiệm vụ và theo dõi nhật ký kiểm toán.", RGBColor(128, 90, 213))
    ]

    for idx, (title, desc, col) in enumerate(roles):
        t = Inches(1.4 + idx * 1.15)
        add_card(s5, Inches(0.8), t, Inches(11.7), Inches(1.0), border_color=col)
        
        tx = s5.shapes.add_textbox(Inches(1.0), t + Inches(0.1), Inches(11.3), Inches(0.8))
        tf = tx.text_frame
        tf.word_wrap = True
        p_t = tf.paragraphs[0]
        p_t.text = title
        p_t.font.name = "Segoe UI"
        p_t.font.size = Pt(12)
        p_t.font.bold = True
        p_t.font.color.rgb = col
        
        p_d = tf.add_paragraph()
        p_d.text = desc
        p_d.font.name = "Segoe UI"
        p_d.font.size = Pt(10.5)
        p_d.font.color.rgb = C_DARK

    set_notes(s5, "Hệ thống PKA-Home phân định năm nhóm vai trò độc lập. Tùy thuộc vào tài khoản đăng nhập, thanh điều hướng sẽ thay đổi động: Quản trị viên có đủ năm phân hệ, Kế toán tập trung vào tài chính và hóa đơn, trong khi Kỹ thuật viên chỉ thao tác trên phiếu sửa chữa sự cố.")

    # =========================================================
    # SLIDE 6: SƠ ĐỒ NGỮ CẢNH
    # =========================================================
    s6 = prs.slides.add_slide(blank_layout)
    add_header(s6, "SƠ ĐỒ NGỮ CẢNH VÀ PHẠM VI HỆ THỐNG")

    img_ctx = os.path.join(assets_dir, 'image2.png')
    if os.path.exists(img_ctx):
        s6.shapes.add_picture(img_ctx, Inches(1.0), Inches(1.4), width=Inches(7.2))

    # Right description
    add_card(s6, Inches(8.5), Inches(1.4), Inches(4.0), Inches(5.5), title="ĐẶC ĐIỂM NGỮ CẢNH", border_color=C_BLUE)
    tx_ctx = s6.shapes.add_textbox(Inches(8.7), Inches(2.1), Inches(3.6), Inches(4.5))
    tf_c = tx_ctx.text_frame
    tf_c.word_wrap = True
    
    ctx_notes = [
        "Hạt nhân PKA-Home: Tiếp nhận và xử lý tập trung mọi nghiệp vụ cư dân, tài chính, tiện ích, phương tiện và sự cố.",
        "Tương tác hai chiều: Cư dân gửi yêu cầu - Bộ phận vận hành phê duyệt và phản hồi kết quả.",
        "Tích hợp dịch vụ Email: Cung cấp mã xác thực OTP phục vụ khôi phục mật khẩu.",
        "Thông báo đẩy FCM: Gửi tin tức khẩn cấp tới thiết bị người dùng.",
        "Vùng lưu trữ Storage: Quản lý hình ảnh sự cố và ủy nhiệm chi riêng tư."
    ]
    for cn in ctx_notes:
        p = tf_c.add_paragraph() if tf_c.paragraphs[0].text else tf_c.paragraphs[0]
        p.text = f"• {cn}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(10.5)
        p.font.color.rgb = C_DARK

    set_notes(s6, "Trên sơ đồ ngữ cảnh, PKA-Home đóng vai trò hạt nhân tiếp nhận và điều phối mọi luồng thông tin giữa cư dân và bộ phận vận hành, đồng thời kết nối với các dịch vụ máy chủ như xác thực, lưu trữ và thông báo đẩy.")

    # =========================================================
    # SLIDE 7: SƠ ĐỒ CA SỬ DỤNG PHÂN HỆ CƯ DÂN & BQL
    # =========================================================
    s7 = prs.slides.add_slide(blank_layout)
    add_header(s7, "SƠ ĐỒ CA SỬ DỤNG CHI TIẾT THEO PHÂN HỆ")

    img_uc_r = os.path.join(assets_dir, 'hinh2_2a_use_case_cu_dan.png')
    img_uc_m = os.path.join(assets_dir, 'hinh2_2b_use_case_ban_quan_ly.png')
    
    if os.path.exists(img_uc_r):
        s7.shapes.add_picture(img_uc_r, Inches(0.8), Inches(1.5), width=Inches(5.7))
    if os.path.exists(img_uc_m):
        s7.shapes.add_picture(img_uc_m, Inches(6.8), Inches(1.5), width=Inches(5.7))

    set_notes(s7, "Hệ thống được thiết kế với 23 ca sử dụng chính, bao phủ từ các thao tác đơn giản như xem thông báo đến các nghiệp vụ phức tạp như điều phối danh sách chờ tiện ích và lập hóa đơn hàng loạt.")

    # =========================================================
    # SLIDE 8: KIẾN TRÚC PHẦN MỀM PHÂN TẦNG
    # =========================================================
    s8 = prs.slides.add_slide(blank_layout)
    add_header(s8, "KIẾN TRÚC PHẦN MỀM PHÂN TẦNG (FEATURE-FIRST)")

    img_arch = os.path.join(assets_dir, 'image4.png')
    if os.path.exists(img_arch):
        s8.shapes.add_picture(img_arch, Inches(0.8), Inches(1.5), width=Inches(6.8))

    add_card(s8, Inches(7.9), Inches(1.5), Inches(4.6), Inches(5.5), title="ƯU ĐIỂM KIẾN TRÚC", border_color=C_BLUE)
    tx_ar = s8.shapes.add_textbox(Inches(8.1), Inches(2.1), Inches(4.2), Inches(4.5))
    tf_a = tx_ar.text_frame
    tf_a.word_wrap = True

    arch_pts = [
        "Kiến trúc Feature-first: Nhóm mã nguồn theo tính năng nghiệp vụ, dễ bảo trì và phân định trách nhiệm.",
        "Tầng Trình diễn (UI): Flutter widgets hỗ trợ co giãn linh hoạt, không tràn màn hình trên thiết bị 360dp.",
        "Tầng Trạng thái: Riverpod providers quản lý vòng đời bất đồng bộ, nạp và tự động làm mới dữ liệu.",
        "Tầng Dữ liệu: Lớp Repositories đóng gói toàn bộ logic gọi mạng và ánh xạ Model chuyển đổi JSON.",
        "Tầng Máy chủ (Supabase): Thực thi RLS, trigger và hàm thủ tục lưu trữ an toàn."
    ]
    for ap in arch_pts:
        p = tf_a.add_paragraph() if tf_a.paragraphs[0].text else tf_a.paragraphs[0]
        p.text = f"• {ap}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(11)
        p.font.color.rgb = C_DARK

    set_notes(s8, "Về mặt kiến trúc, em áp dụng mô hình Feature-first kết hợp Riverpod. Toàn bộ logic giao diện được tách biệt tuyệt đối khỏi các thao tác gọi dữ liệu, giúp mã nguồn mạch lạc, dễ mở rộng và thuận tiện cho việc kiểm thử tự động.")

    # =========================================================
    # SLIDE 9: THIẾT KẾ CƠ SỞ DỮ LIỆU CHI TIẾT (ERD)
    # =========================================================
    s9 = prs.slides.add_slide(blank_layout)
    add_header(s9, "THIẾT KẾ CƠ SỞ DỮ LIỆU QUAN HỆ (ERD)")

    img_erd = os.path.join(assets_dir, 'image7.png')
    if os.path.exists(img_erd):
        s9.shapes.add_picture(img_erd, Inches(0.8), Inches(1.5), width=Inches(7.2))

    add_card(s9, Inches(8.3), Inches(1.5), Inches(4.2), Inches(5.5), title="ĐẶC ĐIỂM DỮ LIỆU", border_color=C_GREEN)
    tx_erd = s9.shapes.add_textbox(Inches(8.5), Inches(2.1), Inches(3.8), Inches(4.5))
    tf_e = tx_erd.text_frame
    tf_e.word_wrap = True

    erd_pts = [
        "16 bảng quan hệ chuẩn hóa: users, apartments, invoices, meter_reading, vehicles, amenities, issues...",
        "Định dạng căn hộ A0110: Mã phòng cấu trúc Block + Tầng (2 số) + Phòng (2 số).",
        "Ràng buộc toàn vẹn: Ràng buộc khóa ngoại CASCADE hoặc RESTRICT ngăn xóa căn hộ đang có người ở.",
        "Tách biệt hạng mục phí: Bảng invoice_items lưu chi tiết điện, nước, quản lý, phí xe máy, ô tô."
    ]
    for ep in erd_pts:
        p = tf_e.add_paragraph() if tf_e.paragraphs[0].text else tf_e.paragraphs[0]
        p.text = f"• {ep}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(11)
        p.font.color.rgb = C_DARK

    set_notes(s9, "Mô hình dữ liệu quan hệ gồm 16 bảng được chuẩn hóa, bảo đảm tính liên kết toàn vẹn từ người dùng, căn hộ đến từng hạng mục chi phí và lịch sử phản ánh sự cố.")

    # =========================================================
    # SLIDE 10: ĐIỂM SÁNG 1 - PHÒNG THỦ 3 LỚP
    # =========================================================
    s10 = prs.slides.add_slide(blank_layout)
    add_header(s10, "ĐIỂM SÁNG 1: PHÒNG THỦ 3 LỚP CHỐNG LEO THANG ĐẶC QUYỀN")

    layers = [
        ("LỚP 1: TRIGGER CƠ SỞ DỮ LIỆU (CSDL)", "Trigger trg_prevent_role_self_escalation chặn sự kiện BEFORE UPDATE. Ném ngoại lệ hủy giao dịch nếu người sửa vai trò không phải Quản trị viên.", C_RED := RGBColor(229, 62, 62)),
        ("LỚP 2: CHÍNH SÁCH PHÂN QUYỀN CẤP BẢN GHI (RLS)", "Chính sách RLS UPDATE áp dụng mệnh đề WITH CHECK (role = (SELECT role FROM users WHERE id = auth.uid())), từ chối mọi gói tin sửa role.", C_ORANGE),
        ("LỚP 3: HÀM THỦ TỤC LƯU TRỮ AN TOÀN (RPC)", "Hàm update_own_profile thực thi dưới quyền SECURITY DEFINER chỉ nhận full_name và phone, triệt tiêu hoàn toàn thuộc tính role khỏi tham số.", C_GREEN)
    ]

    for idx, (title, desc, col) in enumerate(layers):
        t = Inches(1.5 + idx * 1.85)
        add_card(s10, Inches(0.8), t, Inches(11.7), Inches(1.65), title=title, border_color=col)
        
        tx = s10.shapes.add_textbox(Inches(1.0), t + Inches(0.55), Inches(11.3), Inches(1.0))
        tf = tx.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = desc
        p.font.name = "Segoe UI"
        p.font.size = Pt(12)
        p.font.color.rgb = C_DARK
        p.line_spacing = 1.3

    set_notes(s10, "Điểm sáng bảo mật đầu tiên là cơ chế phòng thủ ba lớp chống leo thang đặc quyền. Kể cả khi kẻ tấn công can thiệp vào mã nguồn ứng dụng di động để gửi yêu cầu cập nhật quyền quản trị viên, tầng cơ sở dữ liệu sẽ lập tức phát hiện và hủy giao dịch.")

    # =========================================================
    # SLIDE 11: ĐIỂM SÁNG 2 - TOÀN VẸN DỮ LIỆU TÀI CHÍNH
    # =========================================================
    s11 = prs.slides.add_slide(blank_layout)
    add_header(s11, "ĐIỂM SÁNG 2: TOÀN VẸN DỮ LIỆU TÀI CHÍNH CẤP MÁY CHỦ")

    cards_fin = [
        ("CỘT TÍNH TOÁN CSDL (GENERATED COLUMN)", "Thành tiền (subtotal) của từng mục phí trong invoice_items được tính toán tự động bằng PostgreSQL:\nsubtotal = unit_price * quantity (STORED).\nClient không gửi thành tiền, triệt tiêu gian lận số liệu."),
        ("TRIGGER CỘNG DỒN HÓA ĐƠN MẸ", "Trigger trg_recalc_invoice_total tự động cộng tổng toàn bộ các mục con và cập nhật vào cột total_amount trên bảng invoices mẹ, bảo đảm số tiền luôn khớp 100%."),
        ("LẬP HÓA ĐƠN HÀNG LOẠT QUA RPC", "Hàm generate_valid_bulk_invoices tiền kiểm tra căn hộ thiếu số liệu, tự động đếm số lượng xe máy và ô tô đã duyệt của từng căn hộ để tính phí gửi xe chuẩn xác.")
    ]

    for idx, (title, desc) in enumerate(cards_fin):
        l = Inches(0.8 + idx * 3.95)
        add_card(s11, l, Inches(1.5), Inches(3.75), Inches(5.4), title=title, border_color=C_BLUE)
        
        tx = s11.shapes.add_textbox(l + Inches(0.15), Inches(2.2), Inches(3.45), Inches(4.5))
        tf = tx.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = desc
        p.font.name = "Segoe UI"
        p.font.size = Pt(11)
        p.font.color.rgb = C_DARK
        p.line_spacing = 1.3

    set_notes(s11, "Về mặt tài chính, em loại bỏ hoàn toàn việc tính tiền từ ứng dụng di động. Toàn bộ tiền thành phần và tổng tiền hóa đơn đều do chính hệ quản trị cơ sở dữ liệu tính toán tự động qua cột Generated Column và Trigger máy chủ.")

    # =========================================================
    # SLIDE 12: ĐIỂM SÁNG 3 - ĐẶT TIỆN ÍCH & SỨC CHỨA
    # =========================================================
    s12 = prs.slides.add_slide(blank_layout)
    add_header(s12, "ĐIỂM SÁNG 3: KIỂM SOÁT SỨC CHỨA & DANH SÁCH CHỜ TIỆN ÍCH")

    img_amenity = os.path.join(assets_dir, 'hinh2_13b_tuan_tu_dat_tien_ich.png')
    if os.path.exists(img_amenity):
        s12.shapes.add_picture(img_amenity, Inches(0.8), Inches(1.4), width=Inches(7.2))

    add_card(s12, Inches(8.3), Inches(1.4), Inches(4.2), Inches(5.5), title="CƠ CHẾ ĐIỀU PHỐI", border_color=C_GREEN)
    tx_am = s12.shapes.add_textbox(Inches(8.5), Inches(2.1), Inches(3.8), Inches(4.5))
    tf_am = tx_am.text_frame
    tf_am.word_wrap = True

    am_pts = [
        "Khóa đồng bộ (Concurrency Control): Khóa tiện ích theo ngày/giờ bằng FOR UPDATE tránh cạnh tranh tài nguyên.",
        "Sức chứa thực tế động: Đếm chính xác số khách theo từng loại tiện ích (Bể bơi 30, Gym 20, BBQ 15, Tennis 4).",
        "Danh sách chờ tự động: Nếu kín lịch, tự động tạo booking ở trạng thái WAITLIST an toàn.",
        "Hủy lịch nguyên tử (Atomic RPC): Cư dân tự hủy lịch qua cancel_amenity_booking; máy chủ tự hủy giao dịch và đôn Waitlist."
    ]
    for amp in am_pts:
        p = tf_am.add_paragraph() if tf_am.paragraphs[0].text else tf_am.paragraphs[0]
        p.text = f"• {amp}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(10.5)
        p.font.color.rgb = C_DARK

    set_notes(s12, "Khi đặt các tiện ích có sức chứa giới hạn như bể bơi hay phòng tập thể thao, hệ thống áp dụng khóa giao dịch để giải quyết bài toán đặt chỗ đồng thời, đồng thời hỗ trợ hủy lịch an toàn tự động hoàn tiền và đôn lượt chờ.")

    # =========================================================
    # SLIDE 12b: QUẢN TRỊ TIỆN ÍCH 3 TAB & THÔNG BÁO ĐÍCH
    # =========================================================
    s12b = prs.slides.add_slide(blank_layout)
    add_header(s12b, "QUẢN TRỊ TIỆN ÍCH 3 TAB & THÔNG BÁO PHÂN NHÓM ĐÍCH")

    img_arch_amenity = os.path.join(assets_dir, 'hinh2_15_kien_truc_tien_ich_va_thong_bao.png')
    if os.path.exists(img_arch_amenity):
        s12b.shapes.add_picture(img_arch_amenity, Inches(0.8), Inches(1.4), width=Inches(7.2))

    add_card(s12b, Inches(8.3), Inches(1.4), Inches(4.2), Inches(5.5), title="TÍNH NĂNG ĐỘT PHÁ", border_color=C_BLUE)
    tx_12b = s12b.shapes.add_textbox(Inches(8.5), Inches(2.1), Inches(3.8), Inches(4.5))
    tf_12b = tx_12b.text_frame
    tf_12b.word_wrap = True

    pts_12b = [
        "Quản trị Tiện ích 3 Tab: Phân tách rõ ràng Tab Duyệt lịch (thẻ A7, nút A8, Check-in QR), Tab Cấu hình sức chứa và Tab Lịch bảo trì.",
        "Cấu hình sức chứa linh hoạt: BQL tùy chỉnh trực tiếp max_capacity, giá tiền, tiền cọc và loại hình dùng chung/độc quyền.",
        "Thông báo nhắm đích chính xác: Gửi tin tới Toàn tòa, Theo Block (A/B/C), Theo Tầng hoặc Căn hộ cụ thể, chống loãng thông tin.",
        "Hóa đơn hàng loạt Preflight: Thẩm định danh sách căn hộ và số tiền dự kiến trước khi gọi RPC xuất hóa đơn."
    ]
    for pt in pts_12b:
        p = tf_12b.add_paragraph() if tf_12b.paragraphs[0].text else tf_12b.paragraphs[0]
        p.text = f"• {pt}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(10.5)
        p.font.color.rgb = C_DARK

    set_notes(s12b, "Hệ thống bổ sung phân hệ Quản trị tiện ích 3 Tab hiện đại và cơ chế thông báo phân nhóm đích, giúp ban quản lý vận hành chính xác từng dịch vụ tòa nhà mà không làm phiền những cư dân không liên quan.")

    # =========================================================
    # SLIDE 13: LUỒNG THANH TOÁN MÔ PHỎNG 2 BƯỚC
    # =========================================================
    s13 = prs.slides.add_slide(blank_layout)
    add_header(s13, "LUỒNG THANH TOÁN MÔ PHỎNG VÀ ĐỐI SOÁT HAI BƯỚC")

    img_pay = os.path.join(assets_dir, 'hinh2_13a_tuan_tu_thanh_toan.png')
    if os.path.exists(img_pay):
        s13.shapes.add_picture(img_pay, Inches(0.8), Inches(1.4), width=Inches(7.2))

    add_card(s13, Inches(8.3), Inches(1.4), Inches(4.2), Inches(5.5), title="ĐẶC TÍNH LUỒNG", border_color=C_ORANGE)
    tx_pay = s13.shapes.add_textbox(Inches(8.5), Inches(2.1), Inches(3.8), Inches(4.5))
    tf_p = tx_pay.text_frame
    tf_p.word_wrap = True

    pay_pts = [
        "Đa phương thức: VietQR mô phỏng, Chuyển khoản ngân hàng xác nhận 2 bước, Tiền mặt tại quầy.",
        "Xác nhận hai bước an toàn: Cư dân nộp ủy nhiệm chi -> Trạng thái PENDING -> Kế toán kiểm tra và phê duyệt sang SUCCESS.",
        "Chống gửi lặp (Idempotency): Gửi nhiều yêu cầu liên tiếp vẫn chỉ tạo một giao dịch duy nhất.",
        "Đồng bộ Realtime: Giao diện cư dân tự động chuyển sang thẻ xanh Đã thanh toán ngay khi kế toán duyệt."
    ]
    for pp in pay_pts:
        p = tf_p.add_paragraph() if tf_p.paragraphs[0].text else tf_p.paragraphs[0]
        p.text = f"• {pp}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(10.5)
        p.font.color.rgb = C_DARK

    set_notes(s13, "Quy trình khai báo chỉ số điện nước kết nối trực tiếp với khâu thanh toán. Kế toán sau khi duyệt ảnh công tơ có thể kích hoạt tạo hóa đơn tự động; cư dân sau đó thanh toán ngay qua cổng VietQR mô phỏng hoặc chuyển khoản hai bước.")

    # =========================================================
    # SLIDE 14: KẾT QUẢ KIỂM THỬ TỰ ĐỘNG
    # =========================================================
    s14 = prs.slides.add_slide(blank_layout)
    add_header(s14, "KẾT QUẢ KIỂM THỬ TỰ ĐỘNG & NGHIỆM THU (100% ĐẠT)")

    img_test = os.path.join(assets_dir, 'hinh_kiem_thu_tong_hop.png')
    if os.path.exists(img_test):
        s14.shapes.add_picture(img_test, Inches(0.8), Inches(1.4), width=Inches(7.2))

    add_card(s14, Inches(8.3), Inches(1.4), Inches(4.2), Inches(5.5), title="CHỈ SỐ CHẤT LƯỢNG", border_color=C_GREEN)
    tx_ts = s14.shapes.add_textbox(Inches(8.5), Inches(2.1), Inches(3.8), Inches(4.5))
    tf_ts = tx_ts.text_frame
    tf_ts.word_wrap = True

    t_pts = [
        "Phân tích tĩnh: dart analyze đạt chuẩn sạch 0 Cảnh báo / 0 Lỗi.",
        "Quy mô kiểm thử: 131 tệp kiểm thử tự động trải rộng toàn hệ thống.",
        "Số ca kiểm thử: 408 bài kiểm thử (405 ca logic đạt tuyệt đối 100%).",
        "Bảo mật RLS: Kiểm chứng cư dân không đọc được hóa đơn căn khác.",
        "Giao diện co giãn: Kiểm thử responsive màn hình hẹp 360dp không lỗi tràn màn hình."
    ]
    for tp in t_pts:
        p = tf_ts.add_paragraph() if tf_ts.paragraphs[0].text else tf_ts.paragraphs[0]
        p.text = f"• {tp}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(10.5)
        p.font.color.rgb = C_DARK

    set_notes(s14, "Để bảo đảm phần mềm vận hành ổn định và không phát sinh lỗi tiềm ẩn, em đã xây dựng một bộ test suite gồm 131 tệp với 408 ca kiểm thử tự động. Toàn bộ các ca test logic đều vượt qua 100%, bảo đảm từ phân tích tĩnh đến kiểm thử bảo mật RLS.")

    # =========================================================
    # SLIDE 15: MINH CHỨNG GIAO DIỆN CƯ DÂN (PLACEHOLDER)
    # =========================================================
    s15 = prs.slides.add_slide(blank_layout)
    add_header(s15, "MINH CHỨNG GIAO DIỆN PHÂN HỆ CƯ DÂN")

    # 3 Placeholder cards for mobile screenshots
    card_w = Inches(3.7)
    card_h = Inches(5.4)

    c_titles = [
        "TRANG CHỦ CƯ DÂN (DASHBOARD)",
        "CHI TIẾT HÓA ĐƠN & THANH TOÁN",
        "CHỈ SỐ ĐIỆN NƯỚC & TIỆN ÍCH"
    ]
    c_desc = [
        "Mã phòng A0110, thẻ tổng nợ đỏ nổi bật, thanh thao tác nhanh và thẻ sự cố khẩn cấp.",
        "Phân rã chi tiết tiền điện, nước, phí quản lý kèm cổng thanh toán VietQR / chuyển khoản.",
        "Giao diện chụp ảnh công tơ điện nước và form đặt lịch tiện ích chung cư."
    ]

    for idx, (ct, cd) in enumerate(zip(c_titles, c_desc)):
        l = Inches(0.8 + idx * 4.0)
        card = add_card(s15, l, Inches(1.5), card_w, card_h, title=ct, border_color=C_BLUE)
        
        # Inner dashed box for image
        box = s15.shapes.add_shape(MSO_SHAPE.RECTANGLE, l + Inches(0.2), Inches(2.2), card_w - Inches(0.4), Inches(3.8))
        box.fill.solid()
        box.fill.fore_color.rgb = RGBColor(241, 245, 249)
        box.line.color.rgb = C_BLUE
        box.line.width = Pt(1.5)
        box.line.dash_style = 2 # dashed
        
        p_box = box.text_frame.paragraphs[0]
        p_box.text = f"[CHÚ THÍCH ẢNH CHỤP THỰC TẾ]\n\n{cd}\n\n(Dán ảnh chụp màn hình điện thoại vào đây)"
        p_box.font.name = "Segoe UI"
        p_box.font.size = Pt(10)
        p_box.font.color.rgb = C_MUTED
        p_box.alignment = PP_ALIGN.CENTER

    set_notes(s15, "Kính mời quý thầy cô quan sát giao diện thực tế của phân hệ Cư dân. Trang chủ được thiết kế theo xu hướng Smart Dashboard với tông màu trực quan, hiển thị công nợ tức thì và hỗ trợ các thao tác thanh toán, báo sự cố chỉ với một chạm.")

    # =========================================================
    # SLIDE 16: MINH CHỨNG GIAO DIỆN BAN QUẢN LÝ (PLACEHOLDER)
    # =========================================================
    s16 = prs.slides.add_slide(blank_layout)
    add_header(s16, "MINH CHỨNG GIAO DIỆN PHÂN HỆ BAN QUẢN LÝ")

    m_titles = [
        "BẢNG ĐIỀU KHIỂN (BQL DASHBOARD)",
        "LẬP HÓA ĐƠN HÀNG LOẠT",
        "ĐIỀU PHỐI SỰ CỐ & KPI KỸ THUẬT"
    ]
    m_desc = [
        "Huy hiệu đếm số việc chờ duyệt (liên kết, hóa đơn, sự cố, xe) và biểu đồ xu hướng doanh thu.",
        "Hộp thoại lập hóa đơn hàng loạt tự động tính phí gửi xe máy, ô tô theo từng căn hộ.",
        "Màn hình trao đổi bình luận thời gian thực và biểu đồ KPI đánh giá kỹ thuật viên 1 - 5 sao."
    ]

    for idx, (mt, md) in enumerate(zip(m_titles, m_desc)):
        l = Inches(0.8 + idx * 4.0)
        add_card(s16, l, Inches(1.5), card_w, card_h, title=mt, border_color=C_NAVY)
        
        box = s16.shapes.add_shape(MSO_SHAPE.RECTANGLE, l + Inches(0.2), Inches(2.2), card_w - Inches(0.4), Inches(3.8))
        box.fill.solid()
        box.fill.fore_color.rgb = RGBColor(241, 245, 249)
        box.line.color.rgb = C_NAVY
        box.line.width = Pt(1.5)
        box.line.dash_style = 2
        
        p_box = box.text_frame.paragraphs[0]
        p_box.text = f"[CHÚ THÍCH ẢNH CHỤP THỰC TẾ]\n\n{md}\n\n(Dán ảnh chụp màn hình điện thoại vào đây)"
        p_box.font.name = "Segoe UI"
        p_box.font.size = Pt(10)
        p_box.font.color.rgb = C_MUTED
        p_box.alignment = PP_ALIGN.CENTER

    set_notes(s16, "Đối với phân hệ Ban Quản Lý, bảng điều khiển tập trung toàn bộ các đầu việc tồn đọng dưới dạng thẻ có huy hiệu thông báo số lượng, hỗ trợ lập hóa đơn tự động cho hàng trăm căn hộ và theo dõi điểm đánh giá dịch vụ của từng kỹ thuật viên.")

    # =========================================================
    # SLIDE 17: TIẾN ĐỘ THỰC HIỆN DỰ ÁN
    # =========================================================
    s17 = prs.slides.add_slide(blank_layout)
    add_header(s17, "KẾ HOẠCH VÀ TIẾN ĐỘ THỰC HIỆN (BIỂU ĐỒ GANTT)")

    img_gantt = os.path.join(assets_dir, 'hinh3_1_gantt_tien_do.png')
    if os.path.exists(img_gantt):
        s17.shapes.add_picture(img_gantt, Inches(0.8), Inches(1.5), width=Inches(7.2))

    add_card(s17, Inches(8.3), Inches(1.5), Inches(4.2), Inches(5.4), title="QUẢN LÝ DỰ ÁN", border_color=C_BLUE)
    tx_gt = s17.shapes.add_textbox(Inches(8.5), Inches(2.1), Inches(3.8), Inches(4.5))
    tf_g2 = tx_gt.text_frame
    tf_g2.word_wrap = True

    g_pts = [
        "Khung thời gian: 6 tuần thực hiện nghiêm túc từ khảo sát đến bàn giao.",
        "Kiểm soát phiên bản: Sử dụng Git với quy chuẩn cam kết rõ ràng, quản lý các tệp migration theo thứ tự thời gian.",
        "Quy trình kiểm soát chất lượng: Chạy kiểm thử hồi quy trước mỗi bản cập nhật lớn.",
        "Tách biệt môi trường: Cấu hình khóa bí mật tách khỏi mã nguồn ứng dụng di động."
    ]
    for gp in g_pts:
        p = tf_g2.add_paragraph() if tf_g2.paragraphs[0].text else tf_g2.paragraphs[0]
        p.text = f"• {gp}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(10.5)
        p.font.color.rgb = C_DARK

    set_notes(s17, "Dự án được triển khai có kỷ luật qua sáu giai đoạn trong vòng sáu tuần, mỗi bước đều có mục tiêu và sản phẩm đầu ra rõ ràng, bảo đảm tiến độ bàn giao đúng hạn.")

    # =========================================================
    # SLIDE 18: KẾT LUẬN & HƯỚNG PHÁT TRIỂN
    # =========================================================
    s18 = prs.slides.add_slide(blank_layout)
    add_header(s18, "KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN TƯƠNG LAI")

    add_card(s18, Inches(0.8), Inches(1.5), Inches(5.6), Inches(5.4), title="KẾT QUẢ ĐẠT ĐƯỢC", border_color=C_GREEN)
    tx_res = s18.shapes.add_textbox(Inches(1.0), Inches(2.2), Inches(5.2), Inches(4.5))
    tf_r = tx_res.text_frame
    tf_r.word_wrap = True

    res_pts = [
        "Hoàn thành 100% các tính năng đề ra: 25 yêu cầu chức năng, 10 yêu cầu phi chức năng.",
        "Hiện thực hóa giải pháp bảo vệ dữ liệu ba lớp chống leo thang đặc quyền và toàn vẹn tài chính tại cơ sở dữ liệu.",
        "Hệ thống đạt chất lượng cao: 131 tệp kiểm thử với 408 ca test (100% logic test vượt qua).",
        "Giao diện thân thiện, 100% tiếng Việt chuẩn mực, hỗ trợ co giãn linh hoạt trên mọi kích thước màn hình."
    ]
    for rp in res_pts:
        p = tf_r.add_paragraph() if tf_r.paragraphs[0].text else tf_r.paragraphs[0]
        p.text = f"• {rp}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(11)
        p.font.color.rgb = C_DARK

    add_card(s18, Inches(6.8), Inches(1.5), Inches(5.7), Inches(5.4), title="HƯỚNG PHÁT TRIỂN", border_color=C_ORANGE)
    tx_fut = s18.shapes.add_textbox(Inches(7.0), Inches(2.2), Inches(5.3), Inches(4.5))
    tf_f = tx_fut.text_frame
    tf_f.word_wrap = True

    fut_pts = [
        "Tích hợp Open Banking thực tế: Kết nối API ngân hàng thương mại để tự động gạch nợ hóa đơn thời gian thực.",
        "Ứng dụng thị giác máy tính AI: Huấn luyện mô hình cục bộ trên thiết bị di động hỗ trợ tự động nhận diện chỉ số công tơ điện nước và biển số xe tại sảnh.",
        "Mở rộng đa nền tảng: Đóng gói và phát hành ứng dụng trên nền tảng iOS và phiên bản web dành cho ban quản trị tòa nhà."
    ]
    for fp in fut_pts:
        p = tf_f.add_paragraph() if tf_f.paragraphs[0].text else tf_f.paragraphs[0]
        p.text = f"• {fp}\n"
        p.font.name = "Segoe UI"
        p.font.size = Pt(11)
        p.font.color.rgb = C_DARK

    set_notes(s18, "Đồ án đã hoàn thành toàn bộ các mục tiêu đặt ra, cung cấp một sản phẩm có tính hoàn thiện cao, vừa đáp ứng tốt nghiệp vụ quản lý chung cư, vừa bảo đảm nghiêm ngặt các tiêu chuẩn an toàn thông tin của một hệ thống phần mềm hiện đại.")

    # =========================================================
    # SLIDE 19: LỜI CẢM ƠN & Q&A
    # =========================================================
    s19 = prs.slides.add_slide(blank_layout)
    bg19 = s19.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(7.5))
    bg19.fill.solid()
    bg19.fill.fore_color.rgb = C_NAVY
    bg19.line.fill.background()

    if os.path.exists(logo_path):
        s19.shapes.add_picture(logo_path, Inches(5.65), Inches(1.2), height=Inches(2.0))

    tx19 = s19.shapes.add_textbox(Inches(1.5), Inches(3.4), Inches(10.333), Inches(3.5))
    tf19 = tx19.text_frame
    tf19.word_wrap = True

    p1 = tf19.paragraphs[0]
    p1.alignment = PP_ALIGN.CENTER
    p1.text = "XIN CHÂN THÀNH CẢM ƠN QUÝ THẦY CÔ VÀ HỘI ĐỒNG ĐÁNH GIÁ!"
    p1.font.name = "Segoe UI"
    p1.font.size = Pt(26)
    p1.font.bold = True
    p1.font.color.rgb = C_ORANGE

    p2 = tf19.add_paragraph()
    p2.alignment = PP_ALIGN.CENTER
    p2.text = "\nPHẦN GIẢI ĐÁP CÂU HỎI & ĐÓNG GÓP Ý KIẾN (Q&A)\n"
    p2.font.name = "Segoe UI"
    p2.font.size = Pt(20)
    p2.font.bold = True
    p2.font.color.rgb = C_WHITE

    p3 = tf19.add_paragraph()
    p3.alignment = PP_ALIGN.CENTER
    p3.text = "Sinh viên thực hiện: Phạm Văn Minh - Mã sinh viên: 23010350\nTrường Đại học Phenikaa"
    p3.font.name = "Segoe UI"
    p3.font.size = Pt(13)
    p3.font.color.rgb = RGBColor(226, 232, 240)

    set_notes(s19, "Em xin chân thành cảm ơn quý thầy cô trong Hội đồng đã chú ý lắng nghe bài báo cáo của em. Em rất mong nhận được những ý kiến đóng góp, nhận xét và câu hỏi của quý thầy cô để sản phẩm được hoàn thiện hơn nữa. Em xin trân trọng cảm ơn!")

    out_file = r'c:/Users/ADMIN/StudioProjects/pka_home/docs/Slide_Thuyet_Trinh_Bao_Ve_PKA_Home.pptx'
    prs.save(out_file)
    print(f"Successfully generated PPTX: {out_file} ({os.path.getsize(out_file)} bytes)")

if __name__ == '__main__':
    create_presentation()
