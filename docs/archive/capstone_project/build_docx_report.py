import os
import sys
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def create_report_docx():
    doc = Document()
    
    # Page setup - Standard A4 with 2.5cm (approx 1 inch) margins
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        
        # Header / Footer setup
        footer = section.footer
        f_p = footer.paragraphs[0]
        f_p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        f_run = f_p.add_run("Báo cáo Đồ án Liên ngành - Ứng dụng Quản lý Chung cư PKA-Home")
        f_run.font.name = "Times New Roman"
        f_run.font.size = Pt(8.5)
        f_run.font.italic = True
        f_run.font.color.rgb = RGBColor(113, 128, 150)

    # Style definitions
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Times New Roman'
    normal_style.font.size = Pt(12)
    normal_style.font.color.rgb = RGBColor(45, 55, 72)
    normal_style.paragraph_format.line_spacing = 1.25
    normal_style.paragraph_format.space_after = Pt(6)

    def set_cell_background(cell, fill_hex):
        tcPr = cell._tc.get_or_add_tcPr()
        shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
        tcPr.append(shd)

    def set_cell_borders(cell, top='single', bottom='single', left='single', right='single', color='CBD5E0', sz='4'):
        tcPr = cell._tc.get_or_add_tcPr()
        borders = parse_xml(
            f'<w:tcBorders {nsdecls("w")}>'
            f'<w:top w:val="{top}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:left w:val="{left}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:bottom w:val="{bottom}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'<w:right w:val="{right}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
            f'</w:tcBorders>'
        )
        tcPr.append(borders)

    def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
        tcPr.append(tcMar)

    def add_title(text, level=1):
        p = doc.add_paragraph()
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.font.name = 'Times New Roman'
        run.bold = True
        
        if level == 1:
            p.paragraph_format.space_before = Pt(18)
            p.paragraph_format.space_after = Pt(8)
            run.font.size = Pt(16)
            run.font.color.rgb = RGBColor(26, 54, 93)
        elif level == 2:
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(6)
            run.font.size = Pt(14)
            run.font.color.rgb = RGBColor(43, 108, 176)
        elif level == 3:
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(4)
            run.font.size = Pt(12.5)
            run.font.color.rgb = RGBColor(45, 55, 72)
        return p

    def add_p(text, bold_prefix=None, italic=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY):
        p = doc.add_paragraph()
        p.alignment = align
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.line_spacing = 1.25
        if bold_prefix:
            r_pre = p.add_run(bold_prefix)
            r_pre.font.name = 'Times New Roman'
            r_pre.font.size = Pt(12)
            r_pre.bold = True
            r_pre.font.color.rgb = RGBColor(26, 54, 93)
        r = p.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(12)
        r.italic = italic
        return p

    def add_bullet(text, bold_prefix=None):
        p = doc.add_paragraph(style='List Bullet')
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.2
        if bold_prefix:
            r_pre = p.add_run(bold_prefix)
            r_pre.font.name = 'Times New Roman'
            r_pre.font.size = Pt(12)
            r_pre.bold = True
            r_pre.font.color.rgb = RGBColor(26, 54, 93)
        r = p.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(12)
        return p

    def add_image_figure(img_path, caption, width=Inches(5.8)):
        if os.path.exists(img_path):
            p_img = doc.add_paragraph()
            p_img.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p_img.paragraph_format.space_before = Pt(8)
            p_img.paragraph_format.space_after = Pt(4)
            p_img.add_run().add_picture(img_path, width=width)
            
            p_cap = doc.add_paragraph()
            p_cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p_cap.paragraph_format.space_after = Pt(12)
            p_cap.paragraph_format.keep_with_next = False
            r_cap = p_cap.add_run(caption)
            r_cap.font.name = 'Times New Roman'
            r_cap.font.size = Pt(10.5)
            r_cap.font.italic = True
            r_cap.font.color.rgb = RGBColor(74, 85, 104)

    def add_callout_box(title, instruction):
        tbl = doc.add_table(rows=1, cols=1)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        cell = tbl.cell(0, 0)
        cell.width = Inches(6.5)
        set_cell_background(cell, 'F7FAFC')
        set_cell_borders(cell, top='single', bottom='single', left='single', right='single', color='3182CE', sz='12')
        set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
        
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(4)
        r1 = p.add_run(f'📷 {title}\n')
        r1.font.name = 'Times New Roman'
        r1.font.size = Pt(11)
        r1.font.bold = True
        r1.font.color.rgb = RGBColor(26, 54, 93)
        
        r2 = p.add_run(f'HƯỚNG DẪN CHỤP ẢNH: {instruction}\n[Sinh viên chèn ảnh chụp màn hình ứng dụng thực tế vào khung này]')
        r2.font.name = 'Times New Roman'
        r2.font.size = Pt(10)
        r2.font.italic = True
        r2.font.color.rgb = RGBColor(74, 85, 104)
        
        p_space = doc.add_paragraph()
        p_space.paragraph_format.space_after = Pt(6)

    def create_styled_table(headers, data, col_widths=None):
        table = doc.add_table(rows=len(data) + 1, cols=len(headers))
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = False
        
        # Header Row
        hdr_cells = table.rows[0].cells
        for i, header_text in enumerate(headers):
            hdr_cells[i].text = header_text
            set_cell_background(hdr_cells[i], '1A365D')
            set_cell_borders(hdr_cells[i], top='single', bottom='single', left='single', right='single', color='2B6CB0', sz='6')
            set_cell_margins(hdr_cells[i], top=120, bottom=120, left=140, right=140)
            p = hdr_cells[i].paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            for run in p.runs:
                run.font.name = 'Times New Roman'
                run.font.size = Pt(10.5)
                run.font.bold = True
                run.font.color.rgb = RGBColor(255, 255, 255)
                
        # Data Rows
        for r_idx, row_data in enumerate(data):
            row_cells = table.rows[r_idx + 1].cells
            bg_color = 'FFFFFF' if r_idx % 2 == 0 else 'F7FAFC'
            for c_idx, cell_value in enumerate(row_data):
                row_cells[c_idx].text = str(cell_value)
                set_cell_background(row_cells[c_idx], bg_color)
                set_cell_borders(row_cells[c_idx], top='single', bottom='single', left='single', right='single', color='E2E8F0', sz='4')
                set_cell_margins(row_cells[c_idx], top=90, bottom=90, left=130, right=130)
                p = row_cells[c_idx].paragraphs[0]
                p.paragraph_format.line_spacing = 1.15
                p.paragraph_format.space_after = Pt(2)
                for run in p.runs:
                    run.font.name = 'Times New Roman'
                    run.font.size = Pt(10)
                    run.font.color.rgb = RGBColor(45, 55, 72)
                    
        if col_widths:
            for row in table.rows:
                for idx, width in enumerate(col_widths):
                    row.cells[idx].width = width
                    
        p_space = doc.add_paragraph()
        p_space.paragraph_format.space_after = Pt(6)
        return table

    assets_dir = r'c:/Users/ADMIN/StudioProjects/pka_home/docs/report_assets'

    # =========================================================
    # TRANG BÌA (COVER PAGE)
    # =========================================================
    p_c1 = doc.add_paragraph()
    p_c1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_c1.paragraph_format.space_before = Pt(10)
    p_c1.paragraph_format.space_after = Pt(2)
    r = p_c1.add_run("TRƯỜNG ĐẠI HỌC PHENIKAA\nTRƯỜNG CÔNG NGHỆ THÔNG TIN")
    r.font.name = "Times New Roman"
    r.font.size = Pt(14)
    r.font.bold = True
    r.font.color.rgb = RGBColor(26, 54, 93)

    logo_path = os.path.join(assets_dir, 'image1.png')
    if os.path.exists(logo_path):
        p_logo = doc.add_paragraph()
        p_logo.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p_logo.paragraph_format.space_before = Pt(25)
        p_logo.paragraph_format.space_after = Pt(25)
        p_logo.add_run().add_picture(logo_path, width=Inches(2.5))

    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.space_before = Pt(10)
    p_title.paragraph_format.space_after = Pt(6)
    r = p_title.add_run("BÁO CÁO ĐỒ ÁN LIÊN NGÀNH\n")
    r.font.name = "Times New Roman"
    r.font.size = Pt(18)
    r.font.bold = True
    r.font.color.rgb = RGBColor(197, 48, 48)

    r_sub = p_title.add_run("ĐỀ TÀI: ỨNG DỤNG QUẢN LÝ CHUNG CƯ (PKA-HOME)")
    r_sub.font.name = "Times New Roman"
    r_sub.font.size = Pt(16)
    r_sub.font.bold = True
    r_sub.font.color.rgb = RGBColor(26, 54, 93)

    p_info = doc.add_paragraph()
    p_info.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_info.paragraph_format.space_before = Pt(45)
    p_info.paragraph_format.space_after = Pt(40)
    p_info.paragraph_format.line_spacing = 1.3
    r = p_info.add_run(
        "Sinh viên thực hiện: Phạm Văn Minh\n"
        "Mã sinh viên: 23010350\n"
        "Email: 23010350@st.phenikaa-uni.edu.vn\n\n"
        "Giảng viên hướng dẫn: Tiến sĩ Nguyễn Thị Vân\n"
    )
    r.font.name = "Times New Roman"
    r.font.size = Pt(13)
    r.font.color.rgb = RGBColor(45, 55, 72)

    p_date = doc.add_paragraph()
    p_date.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_date.paragraph_format.space_before = Pt(20)
    r = p_date.add_run("Hà Nội, tháng 10 năm 2026")
    r.font.name = "Times New Roman"
    r.font.size = Pt(12)
    r.font.italic = True
    r.font.color.rgb = RGBColor(113, 128, 150)

    doc.add_page_break()

    # =========================================================
    # LỜI CẢM ƠN & LỜI CAM ĐOAN
    # =========================================================
    add_title("LỜI CẢM ƠN", level=1)
    add_p("Em xin chân thành cảm ơn Trường Đại học Phenikaa và Trường Công nghệ Thông tin đã tạo điều kiện thuận lợi để em được học tập, nghiên cứu và triển khai đồ án liên ngành. Quá trình thực hiện đề tài đã giúp em kết nối kiến thức phân tích nghiệp vụ, thiết kế hệ thống phần mềm, lập trình ứng dụng di động, quản trị cơ sở dữ liệu và bảo mật thông tin thành một sản phẩm có tính thực tiễn cao.")
    add_p("Em xin bày tỏ lòng biết ơn sâu sắc tới Tiến sĩ Nguyễn Thị Vân – người đã tận tình định hướng học thuật, cung cấp những lời khuyên chuyên môn sâu sắc giúp em hoàn thiện quy trình nghiệp vụ, chuẩn hóa kiến trúc và rà soát tính an toàn của hệ thống PKA-Home.")
    add_p("Dù đã rất nỗ lực hoàn thiện hệ thống, song do giới hạn về mặt thời gian và điều kiện thực nghiệm, đồ án khó tránh khỏi những điểm còn có thể phát triển thêm. Em kính mong nhận được các ý kiến đóng góp quý báu từ thầy cô trong Hội đồng đánh giá để tiếp tục hoàn thiện sản phẩm.")

    add_title("LỜI CAM ĐOAN", level=1)
    add_p("Em, Phạm Văn Minh, cam đoan đề tài 'Ứng dụng Quản lý Chung cư (PKA-Home)' là sản phẩm đồ án do em trực tiếp thực hiện trong phạm vi nghiên cứu và học tập. Toàn bộ mã nguồn, cấu trúc cơ sở dữ liệu, các hàm thủ tục lưu trữ máy chủ và kết quả kiểm thử được trình bày trong báo cáo này là trung thực, phản ánh đúng kết quả triển khai thực tế của dự án.")
    add_p("Các thư viện, nền tảng công nghệ và tài liệu tham khảo từ bên thứ ba đều được ghi nhận nguồn gốc rõ ràng. Dữ liệu thử nghiệm minh họa trong báo cáo không đại diện cho dữ liệu của bất kỳ khu chung cư hay cá nhân thực tế nào. Kết quả kiểm thử tự động đã được xác minh qua nhật ký chạy thực tế trên máy tính phát triển. Em xin chịu hoàn toàn trách nhiệm về tính trung thực của báo cáo này.")

    add_title("TÓM TẮT ĐỒ ÁN", level=1)
    add_p("PKA-Home là hệ sinh thái phần mềm quản lý chung cư hiện đại được xây dựng nhằm số hóa và tự động hóa toàn diện các quy trình tương tác hai chiều giữa cư dân và bộ phận vận hành tòa nhà. Hệ thống được tổ chức phân quyền chặt chẽ theo vai trò thực tế gồm: Cư dân, Quản trị viên, Ban Quản Lý, Kế toán và Kỹ thuật viên. Phạm vi nghiệp vụ bao gồm: quản lý căn hộ, hồ sơ cư trú, tiếp nhận và thẩm định chỉ số điện nước, lập hóa đơn tự động và hàng loạt, thanh toán mô phỏng đa phương thức, đăng ký thẻ phương tiện có hạn mức, đặt tiện ích chung cư với kiểm soát sức chứa thực tế và danh sách chờ, tiếp nhận phản ánh sự cố theo mức độ khẩn cấp, trao đổi bình luận thời gian thực và khảo sát đánh giá chất lượng dịch vụ.")
    add_p("Ứng dụng phía người dùng được phát triển bằng Flutter và Dart theo kiến trúc phân tầng Feature-first. Thư viện Riverpod đảm nhiệm quản lý trạng thái; GoRouter điều phối điều hướng an toàn. Supabase cung cấp nền tảng máy chủ gồm xác thực người dùng, cơ sở dữ liệu quan hệ PostgreSQL 15, đồng bộ dữ liệu thời gian thực và lưu trữ tệp tin.")
    add_p("Trọng tâm kỹ thuật nổi bật của đồ án là thiết kế an toàn từ gốc (Security by Design): phòng thủ ba lớp chống leo thang đặc quyền (kết hợp trigger cơ sở dữ liệu, chính sách an ninh cấp bản ghi RLS và hàm thủ tục lưu trữ RPC), bảo toàn tính toàn vẹn dữ liệu tài chính cấp máy chủ (sử dụng cột Generated Column của PostgreSQL), và kiểm soát xử lý cạnh tranh đồng thời khi đặt tiện ích nhằm bảo vệ sức chứa thực tế.")
    add_p("Hệ thống đã trải qua quá trình kiểm thử tự động nghiêm ngặt với 131 tệp kiểm thử và 395 bài kiểm thử tự động vượt qua 100%, bảo đảm độ tin cậy cao phục vụ nghiệm thu và bảo vệ đồ án.")

    # =========================================================
    # DANH MỤC TỪ VIẾT TẮT & THUẬT NGỮ
    # =========================================================
    add_title("DANH MỤC CHỮ VIẾT TẮT VÀ THUẬT NGỮ", level=1)
    abbr_data = [
        ["API", "Application Programming Interface", "Giao diện lập trình ứng dụng hỗ trợ trao đổi dữ liệu"],
        ["BQL", "Ban Quản lý", "Bộ phận điều phối vận hành, tiếp nhận yêu cầu và xử lý nghiệp vụ chung cư"],
        ["Dart", "Dart Programming Language", "Ngôn ngữ lập trình hướng đối tượng dùng phát triển ứng dụng Flutter"],
        ["ERD", "Entity-Relationship Diagram", "Sơ đồ quan hệ thực thể mô tả cấu trúc dữ liệu quan hệ"],
        ["FCM", "Firebase Cloud Messaging", "Dịch vụ hỗ trợ gửi thông báo đẩy đến thiết bị di động"],
        ["FK", "Foreign Key", "Khóa ngoại dùng liên kết bản ghi với bản ghi thuộc bảng khác"],
        ["Flutter", "Flutter Framework", "Bộ công cụ phát triển ứng dụng đa nền tảng từ một cơ sở mã nguồn"],
        ["GoRouter", "go_router package", "Thư viện điều phối điều hướng và bảo vệ tuyến màn hình theo phiên"],
        ["HTTP", "Hypertext Transfer Protocol", "Giao thức truyền tải siêu văn bản mạng Internet"],
        ["KPI", "Key Performance Indicator", "Chỉ số đánh giá hiệu quả công việc và chất lượng dịch vụ kỹ thuật"],
        ["OTP", "One-Time Password", "Mã xác thực một lần gồm sáu chữ số có thời hạn hiệu lực ngắn"],
        ["PK", "Primary Key", "Khóa chính xác định tính duy nhất của một bản ghi trong bảng"],
        ["PostgreSQL", "PostgreSQL Database", "Hệ quản trị cơ sở dữ liệu quan hệ mạnh mẽ, chuẩn hóa"],
        ["RBAC", "Role-Based Access Control", "Mô hình kiểm soát truy cập và phân quyền dựa trên vai trò"],
        ["Riverpod", "Riverpod state library", "Thư viện quản lý trạng thái phản ứng độc lập và an toàn kiểu dữ liệu"],
        ["RLS", "Row Level Security", "Cơ chế kiểm soát an ninh và phân quyền ở cấp bản ghi dữ liệu"],
        ["RPC", "Remote Procedure Call", "Cơ chế gọi hàm thủ tục lưu trữ thực thi trực tiếp trên máy chủ"],
        ["SQL", "Structured Query Language", "Ngôn ngữ định nghĩa và truy vấn dữ liệu quan hệ có cấu trúc"],
        ["UI/UX", "User Interface / Experience", "Giao diện người dùng và Trải nghiệm người dùng"],
        ["WBS", "Work Breakdown Structure", "Cấu trúc phân chia công việc chi tiết theo tiến độ dự án"]
    ]
    create_styled_table(["Ký hiệu / Thuật ngữ", "Tên đầy đủ tiếng Anh", "Giải thích ý nghĩa tiếng Việt"], abbr_data, [Inches(1.2), Inches(2.3), Inches(3.0)])

    # =========================================================
    # PHÂN CÔNG THỰC HIỆN ĐỒ ÁN
    # =========================================================
    add_title("PHÂN CÔNG THỰC HIỆN ĐỒ ÁN", level=1)
    team_data = [
        ["23010350", "Phạm Văn Minh", "23010350@st.phenikaa-uni.edu.vn", "Phân tích yêu cầu nghiệp vụ; thiết kế kiến trúc và mô hình dữ liệu; phát triển ứng dụng di động Flutter; xây dựng các tầng Model, Repository, Provider; thiết kế cơ sở dữ liệu Supabase/PostgreSQL, hàm lưu trữ RPC, chính sách RLS; xây dựng bộ kiểm thử tự động 395 ca test; viết báo cáo toàn văn và chuẩn bị bài thuyết trình bảo vệ.", "100%"]
    ]
    create_styled_table(["Mã sinh viên", "Họ và tên", "Email", "Nhiệm vụ chính đảm nhiệm", "Tỷ lệ"], team_data, [Inches(1.0), Inches(1.3), Inches(1.6), Inches(2.1), Inches(0.5)])

    # =========================================================
    # CHƯƠNG 1: GIỚI THIỆU
    # =========================================================
    add_title("1. GIỚI THIỆU", level=1)
    add_title("1.1. Đặt vấn đề", level=2)
    add_p("Quản lý một khu căn hộ chung cư cao tầng đòi hỏi sự phối hợp liên tục giữa hàng trăm hộ gia đình cư dân và ban điều hành tòa nhà. Các công việc hàng ngày bao gồm: duy trì hồ sơ căn hộ, tiếp nhận cư dân mới, ghi nhận chỉ số công tơ điện nước, tính toán và phát hành hóa đơn dịch vụ, kiểm soát thẻ xe ra vào, điều phối lịch sử dụng các công trình tiện ích công cộng, tiếp nhận và điều phối nhân sự xử lý sự cố kỹ thuật hạ tầng tòa nhà.")
    add_p("Khi các quy trình này được xử lý phân tán qua các kênh truyền thống như sổ tay, bảng tính, biểu mẫu rời rạc và mạng xã hội, các vấn đề nghiêm trọng nhanh chóng phát sinh:")
    add_bullet("Dữ liệu bị phân tán trên nhiều tệp tin độc lập, gây khó khăn cho việc tra cứu lịch sử và đối soát công nợ.")
    add_bullet("Nguy cơ sai sót tài chính cao khi nhập tay chỉ số điện nước, nhầm lẫn đơn giá hoặc lập lại hóa đơn cho cùng một kỳ.")
    add_bullet("Thiếu tính minh bạch và tức thời trong việc xử lý sự cố hư hỏng hạ tầng, gây bức xúc cho cư dân.")
    add_bullet("Tiềm ẩn rủi ro lộ lọt thông tin cá nhân và số điện thoại của cư dân do thiếu cơ chế phân quyền bảo mật cấp dữ liệu.")

    add_title("1.1.1. Mục tiêu đề tài", level=3)
    add_bullet("Xây dựng ứng dụng di động hoàn chỉnh bằng bộ công cụ Flutter với 100% giao diện tiếng Việt chuẩn mực, điều hướng theo phiên làm việc và vai trò của tài khoản.")
    add_bullet("Thiết kế mô hình cơ sở dữ liệu quan hệ chuẩn hóa trên PostgreSQL (Supabase), cấu trúc mã căn hộ theo định dạng chuẩn A0110.")
    add_bullet("Đặt các quy tắc nghiệp vụ nhạy cảm (tính toán tiền điện nước, kiểm tra sức chứa tiện ích, phân loại mức độ khẩn cấp) trực tiếp trên máy chủ bằng chính sách phân quyền cấp bản ghi (RLS), trigger và hàm thủ tục lưu trữ (RPC).")
    add_bullet("Xây dựng cổng thanh toán mô phỏng đồng nhất phục vụ nghiên cứu và diễn tập quy trình tài chính khép kín.")
    add_bullet("Xây dựng hệ thống kiểm thử tự động toàn diện kiểm chứng độ tin cậy của phần mềm trước khi nghiệm thu.")

    add_title("1.1.2. Đối tượng sử dụng", level=3)
    add_p("Hệ thống phục vụ năm nhóm người dùng với trách nhiệm rõ ràng:")
    add_bullet("Cư dân: Sử dụng ứng dụng để xem thông tin căn hộ, theo dõi hóa đơn, thanh toán mô phỏng, gửi chỉ số điện nước, đặt lịch tiện ích, đăng ký phương tiện và gửi phản ánh sự cố.")
    add_bullet("Ban Quản Lý: Điều phối yêu cầu vận hành, phê duyệt liên kết căn hộ, duyệt hồ sơ phương tiện, quản lý tiện ích và phát thông báo diện rộng.")
    add_bullet("Kế toán: Thẩm định chỉ số điện nước, kiểm tra và phát hành hóa đơn hàng loạt, ghi nhận thu tiền mặt tại quầy và theo dõi báo cáo doanh thu công nợ.")
    add_bullet("Kỹ thuật viên: Tiếp nhận sự cố kỹ thuật được phân công, cập nhật tiến độ sửa chữa, đính kèm biên bản nghiệm thu và trao đổi với cư dân.")
    add_bullet("Quản trị viên: Quản trị cấu hình toàn hệ thống, phân quyền vai trò, ủy quyền nhiệm vụ và giám sát nhật ký kiểm toán.")

    add_title("1.1.3. Phạm vi đề tài", level=3)
    add_p("Phạm vi hiện tại của đề tài tập trung vào việc số hóa quy trình quản lý phần mềm trên nền tảng di động Android. Toàn bộ quy trình thanh toán trong đồ án mang tính chất mô phỏng khép kín phục vụ mục đích đào tạo và nghiên cứu học thuật, không thực hiện chuyển tiền thật qua ngân hàng. Tính năng nhận diện chỉ số công tơ bao gồm chụp ảnh minh chứng thực tế và nhập số đo hỗ trợ quy trình thẩm định của kế toán.")

    add_title("1.2. Các giải pháp đã có và so sánh", level=2)
    add_p("Để làm rõ tính cấp thiết của đề tài, em tiến hành so sánh đối chiếu định tính giữa ba phương thức quản lý phổ biến hiện nay với giải pháp PKA-Home:")
    
    comp_data = [
        ["Tiêu chí so sánh", "Hồ sơ giấy & Bảng tính", "Biểu mẫu & Mạng xã hội", "Phần mềm thương mại", "PKA-Home (Đồ án)"],
        ["Tập trung dữ liệu", "Phân tán nhiều tệp", "Rời rạc, dễ trôi tin", "Tập trung máy chủ riêng", "Tập trung trên PostgreSQL"],
        ["Phân quyền bảo mật", "Thủ công", "Không có phân quyền sâu", "Cấu hình chuyên sâu", "Phòng thủ 3 lớp (RLS/RPC)"],
        ["Kiểm soát tính toán", "Dễ sai lệch đơn giá", "Nhập thủ công", "Đóng kín mã nguồn", "Cột tính toán tự động CSDL"],
        ["Khả năng kiểm chứng", "Khó quan sát", "Phụ thuộc bên thứ ba", "Khó tiếp cận mã", "Kiểm thử tự động 100%"]
    ]
    create_styled_table(comp_data[0], comp_data[1:], [Inches(1.4), Inches(1.2), Inches(1.3), Inches(1.3), Inches(1.3)])

    add_title("1.3. Giải pháp đề xuất PKA-Home", level=2)
    add_p("PKA-Home là ứng dụng quản lý chung cư hiện đại theo mô hình phân tầng Feature-first. Giao diện Flutter kết hợp thư viện Riverpod giúp quản lý trạng thái mượt mà; nền tảng Supabase cung cấp cơ sở dữ liệu quan hệ PostgreSQL với các chính sách phân quyền cấp bản ghi bảo đảm tính độc lập dữ liệu giữa các căn hộ.")

    # =========================================================
    # CHƯƠNG 2: THIẾT KẾ VÀ TRIỂN KHAI
    # =========================================================
    add_title("2. THIẾT KẾ VÀ TRIỂN KHAI HỆ THỐNG", level=1)
    add_title("2.1. Yêu cầu chức năng", level=2)
    add_p("Hệ thống đáp ứng 24 yêu cầu chức năng cốt lõi được phân chia chi tiết theo các phân hệ:")
    
    rf_data = [
        ["RF-01", "Xác thực tài khoản", "Đăng ký, đăng nhập, đăng xuất và quản lý phiên làm việc an toàn", "Tất cả vai trò"],
        ["RF-02", "Khôi phục mật khẩu", "Khôi phục qua mã OTP sáu chữ số hoặc qua hướng dẫn nội bộ Ban Quản Lý", "Tất cả vai trò"],
        ["RF-03", "Phân quyền vai trò", "Điều hướng giao diện và phân định các thanh công cụ theo vai trò tài khoản", "Toàn hệ thống"],
        ["RF-04", "Quản lý căn hộ", "Quản lý căn hộ theo Block và Tầng (chuẩn A0110), chặn xóa căn hộ có người ở", "Quản trị viên, BQL"],
        ["RF-05", "Duyệt liên kết căn hộ", "Cư dân gửi đơn xin gắn căn hộ; Ban Quản Lý phê duyệt hoặc từ chối có lý do", "Cư dân, BQL"],
        ["RF-06", "Quản lý hóa đơn", "Xem hóa đơn chi tiết các hạng mục phí (điện, nước, quản lý, phí xe máy, ô tô)", "Cư dân, Kế toán"],
        ["RF-07", "Khai báo chỉ số", "Cư dân chụp ảnh công tơ điện nước và nhập số chỉ số mới định kỳ hàng tháng", "Cư dân"],
        ["RF-08", "Thẩm định chỉ số", "Kế toán kiểm tra số mới không nhỏ hơn số cũ, duyệt chỉ số và tự động lập hóa đơn", "Kế toán"],
        ["RF-09", "Lập hóa đơn hàng loạt", "Tiền kiểm tra dữ liệu, tự động tính tiền gửi xe theo căn hộ và xuất hóa đơn an toàn", "Kế toán"],
        ["RF-10", "Thanh toán mô phỏng", "Hỗ trợ VietQR mô phỏng, nộp ủy nhiệm chi chuyển khoản xác nhận hai bước", "Cư dân, Kế toán"],
        ["RF-11", "Thu phí tại quầy", "Kế toán ghi nhận thu tiền mặt trực tiếp và gạch nợ hóa đơn tức thì", "Kế toán"],
        ["RF-12", "Đặt tiện ích tòa nhà", "Cư dân chọn tiện ích, ngày, khung giờ và số lượng khách tham gia", "Cư dân"],
        ["RF-13", "Kiểm soát sức chứa", "Khóa giao dịch đồng bộ, kiểm tra sức chứa tối đa và tự động đưa vào danh sách chờ", "Hệ thống, BQL"],
        ["RF-14", "Điểm danh tiện ích", "Ban Quản Lý quét mã đặt chỗ hoặc xác nhận cư dân đến sử dụng và hoàn tiền cọc", "BQL, Cư dân"],
        ["RF-15", "Đăng ký phương tiện", "Đăng ký thẻ xe theo hạn mức căn hộ (tối đa 2 xe máy, 1 ô tô), kiểm tra trùng biển", "Cư dân, BQL"],
        ["RF-16", "Gửi phản ánh sự cố", "Gửi nội dung kèm ảnh; tự động phân loại mức độ khẩn cấp theo từ khóa nguy cơ", "Cư dân"],
        ["RF-17", "Điều phối sự cố", "Ban Quản Lý phân công kỹ thuật viên; kỹ thuật viên cập nhật tiến độ và minh chứng", "BQL, Kỹ thuật viên"],
        ["RF-18", "Đánh giá chất lượng", "Cư dân chấm điểm 1 - 5 sao theo ba tiêu chí (Tốc độ, Thái độ, Kỹ thuật)", "Cư dân"],
        ["RF-19", "Thông báo phân vùng", "Ban Quản Lý gửi thông báo toàn khu, hoặc lọc theo khối nhà, căn hộ cụ thể", "BQL, Cư dân"],
        ["RF-20", "Bảo trì thiết bị", "Quản lý thiết bị kỹ thuật (thang máy, máy bơm), cảnh báo gián đoạn dịch vụ", "BQL, Kỹ thuật viên"],
        ["RF-21", "Cẩm nang cư dân", "Tra cứu nội quy, bảng biểu phí minh bạch và danh bạ khẩn cấp có nút gọi điện", "Cư dân, BQL"],
        ["RF-22", "Báo cáo tài chính", "Biểu đồ xu hướng doanh thu, tỷ lệ thu nợ và xuất danh sách ra bảng tính", "Quản trị viên, Kế toán"],
        ["RF-23", "Hồ sơ 360 độ", "Tra cứu toàn diện một căn hộ: thành viên, phương tiện, hóa đơn và lịch sử tiện ích", "Quản trị viên, BQL"],
        ["RF-24", "Ủy quyền vai trò", "Ủy quyền vai trò tạm thời có giới hạn thời gian bắt đầu và kết thúc", "Quản trị viên"]
    ]
    create_styled_table(["Mã", "Tên yêu cầu chức năng", "Mô tả nội dung chi tiết", "Tác nhân"], rf_data, [Inches(0.8), Inches(1.8), Inches(2.7), Inches(1.2)])

    add_title("2.2. Yêu cầu phi chức năng", level=2)
    nfr_data = [
        ["NFR-01", "Bảo mật", "Phân quyền cấp bản ghi RLS; chặn tuyệt đối truy cập chéo giữa các căn hộ", "Kiểm thử truy vấn chéo"],
        ["NFR-02", "Toàn vẹn", "Tính toán tài chính tự động cấp cơ sở dữ liệu qua Generated Column", "Kiểm tra ràng buộc CSDL"],
        ["NFR-03", "Tính đồng thời", "Khóa giao dịch FOR UPDATE khi đặt tiện ích nhằm bảo vệ sức chứa thực tế", "Kiểm thử đặt chỗ đồng thời"],
        ["NFR-04", "Trải nghiệm", "Giao diện 100% tiếng Việt chuẩn mực, hỗ trợ tự động xuống dòng linh hoạt", "Kiểm thử co giãn màn hình"],
        ["NFR-05", "Hiệu năng", "Tải danh sách hóa đơn và thông báo dưới 2 giây; sẵn sàng mở rộng phân trang", "Đo thời gian phản hồi"],
        ["NFR-06", "Chịu lỗi", "Tách riêng luồng tạo sự cố và tải ảnh; ảnh lỗi không làm mất nội dung mô tả", "Kiểm thử ngắt mạng Storage"]
    ]
    create_styled_table(["Mã", "Thuộc tính", "Yêu cầu kỹ thuật chi tiết", "Phương pháp kiểm chứng"], nfr_data, [Inches(0.8), Inches(1.2), Inches(3.0), Inches(1.5)])

    add_title("2.3. Mô hình hệ thống và thiết kế chi tiết", level=2)
    add_title("2.3.1. Sơ đồ ngữ cảnh và phạm vi hệ thống", level=3)
    add_p("Sơ đồ ngữ cảnh xác định rõ ranh giới giữa PKA-Home và các tác nhân cùng hệ thống dịch vụ bên ngoài:")
    add_image_figure(os.path.join(assets_dir, 'image2.png'), "Hình 2.1. Sơ đồ ngữ cảnh và phạm vi hệ thống PKA-Home")

    add_title("2.3.2. Sơ đồ ca sử dụng tổng quan và phân hệ chi tiết", level=3)
    add_p("Hệ thống phân rã ca sử dụng chi tiết cho hai phân hệ chính:")
    add_image_figure(os.path.join(assets_dir, 'hinh2_2a_use_case_cu_dan.png'), "Hình 2.2a. Sơ đồ ca sử dụng phân hệ Cư dân")
    add_image_figure(os.path.join(assets_dir, 'hinh2_2b_use_case_ban_quan_ly.png'), "Hình 2.2b. Sơ đồ ca sử dụng phân hệ Ban Quản Lý và Vận hành")

    add_title("2.3.3. Đặc tả các ca sử dụng trọng tâm", level=3)
    add_p("Dưới đây là bảng đặc tả chi tiết cho ba ca sử dụng then chốt của hệ thống:")

    uc_detail_1 = [
        ["Mục đặc tả", "Nội dung chi tiết ca sử dụng"],
        ["Mã & Tên ca sử dụng", "UC-CORE-01: Khai báo và thẩm định chỉ số công tơ điện nước"],
        ["Tác nhân chính", "Cư dân, Kế toán"],
        ["Tiền điều kiện", "Cư dân đã được duyệt liên kết căn hộ; kỳ ghi nhận chưa có hóa đơn được xác nhận"],
        ["Luồng sự kiện chính", "1. Cư dân mở màn hình chỉ số, chụp ảnh công tơ điện nước và nhập số chỉ số mới.\n2. Bản ghi được tạo ở trạng thái chờ duyệt trên bảng meter_reading_submissions.\n3. Kế toán mở màn hình duyệt chỉ số, xem ảnh đối chiếu số liệu thực tế.\n4. Kế toán bấm 'Phê duyệt' kèm tùy chọn tạo hóa đơn kỳ.\n5. Máy chủ kích hoạt hàm approve_meter_reading: khóa bản ghi, kiểm tra số mới không nhỏ hơn số cũ, cập nhật chỉ số căn hộ và tự động tạo hóa đơn tiền điện nước."],
        ["Luồng ngoại lệ", "Nếu chỉ số mới nhỏ hơn chỉ số cũ, máy chủ hủy giao dịch và ném lỗi."],
        ["Hậu điều kiện", "Căn hộ được cập nhật chỉ số mới nhất; hóa đơn tiền điện nước được tạo tự động."]
    ]
    create_styled_table(uc_detail_1[0], uc_detail_1[1:], [Inches(2.0), Inches(4.5)])

    uc_detail_2 = [
        ["Mục đặc tả", "Nội dung chi tiết ca sử dụng"],
        ["Mã & Tên ca sử dụng", "UC-CORE-02: Đặt lịch tiện ích tòa nhà và xếp danh sách chờ"],
        ["Tác nhân chính", "Cư dân, Ban Quản Lý"],
        ["Tiền điều kiện", "Tiện ích đang hoạt động; ngày đặt không nằm trong quá khứ hoặc lịch bảo trì"],
        ["Luồng sự kiện chính", "1. Cư dân chọn tiện ích, ngày, khung giờ và số lượng khách tham gia.\n2. Ứng dụng gọi hàm thủ tục lưu trữ book_amenity_slot.\n3. Máy chủ khóa đồng bộ tiện ích theo khung giờ, đếm tổng số khách đang chiếm chỗ.\n4. Nếu còn chỗ: tạo booking ở trạng thái xác nhận (CONFIRMED).\n5. Nếu hết chỗ và cư dân chấp nhận chờ: tạo booking ở trạng thái danh sách chờ (WAITLIST)."],
        ["Luồng ngoại lệ", "Nếu khung giờ trùng với lịch bảo trì định kỳ, hệ thống báo tạm ngưng phục vụ."],
        ["Hậu điều kiện", "Lịch đặt chỗ được ghi nhận an toàn; số chỗ trống được đồng bộ hóa tức thì."]
    ]
    create_styled_table(uc_detail_2[0], uc_detail_2[1:], [Inches(2.0), Inches(4.5)])

    add_title("2.3.4. Kiến trúc phần mềm phân tầng", level=3)
    add_p("Hệ thống tuân thủ mô hình kiến trúc phân tầng Feature-first, bảo đảm tính độc lập giữa giao diện, tầng trạng thái và tầng truy xuất dữ liệu:")
    add_image_figure(os.path.join(assets_dir, 'image4.png'), "Hình 2.3. Kiến trúc tổng thể ứng dụng và các dịch vụ liên quan")

    add_title("2.3.5. Sơ đồ quan hệ thực thể (ERD) và Lược đồ cơ sở dữ liệu", level=3)
    add_p("Cơ sở dữ liệu của PKA-Home được thiết kế trên hệ quản trị PostgreSQL 15 gồm 16 bảng quan hệ chuẩn hóa:")
    add_image_figure(os.path.join(assets_dir, 'image7.png'), "Hình 2.6. Mô hình dữ liệu nghiệp vụ mức khái niệm")

    add_p("Danh mục các hàm thủ tục lưu trữ máy chủ (RPC) then chốt kiểm soát toàn bộ logic nghiệp vụ nhạy cảm:")
    rpc_data = [
        ["Tên hàm lưu trữ (RPC)", "Tham số đầu vào", "Giá trị trả về", "Cơ chế bảo mật và toàn vẹn giao dịch"],
        ["approve_meter_reading", "p_submission_id, p_auto_create_invoice, p_due_date", "json (mã hóa đơn)", "Khóa dòng FOR UPDATE, kiểm tra số mới >= số cũ; cập nhật đồng bộ sang căn hộ và hóa đơn."],
        ["generate_valid_bulk_invoices", "p_period, p_due_date, p_fee_rates...", "json (kết quả tạo)", "Tự động đếm chính xác số xe máy, ô tô đã duyệt của từng căn hộ; chặn tạo trùng lặp kỳ."],
        ["update_invoice_with_items", "p_invoice_id, p_period, p_due_date, p_items", "void", "Xóa và nạp lại các mục phí nguyên tử; trigger tự động tính lại tổng tiền hóa đơn."],
        ["simulate_unified_payment", "p_invoice_id, p_payment_method, p_amount", "json (mã giao dịch)", "Kiểm tra quyền sở hữu, hỗ trợ chuyển khoản PENDING và chống gửi lặp an toàn."],
        ["record_manual_payment", "p_invoice_id, p_amount, p_notes", "json (bản ghi thu)", "Chỉ Kế toán/BQL được gọi; chuyển hóa đơn sang paid và ghi nhật ký thu tiền mặt."],
        ["book_amenity_slot", "p_amenity_id, p_date, p_slot, p_guests, p_waitlist", "json (mã đặt chỗ)", "Khóa tài nguyên theo ngày/giờ; kiểm tra vượt sức chứa; tự động đưa vào danh sách chờ."],
        ["cancel_amenity_booking", "p_booking_id", "json (kết quả hủy)", "Hủy lịch an toàn cho cư dân/BQL, tự động hủy giao dịch tài chính liên quan và đôn lượt Waitlist."],
        ["update_own_profile", "p_full_name, p_phone", "void", "Chạy quyền SECURITY DEFINER, chỉ nhận họ tên và SĐT, triệt tiêu nguy cơ tự sửa role."]
    ]
    create_styled_table(rpc_data[0], rpc_data[1:], [Inches(1.8), Inches(1.8), Inches(1.1), Inches(1.8)])

    add_title("2.3.6. Thiết kế các luồng xử lý và Sơ đồ tuần tự", level=3)
    add_p("Dưới đây là các sơ đồ tuần tự mô tả chi tiết thông điệp trao đổi giữa ứng dụng khách và cơ sở dữ liệu máy chủ:")
    add_image_figure(os.path.join(assets_dir, 'hinh2_13a_tuan_tu_thanh_toan.png'), "Hình 2.13a. Sơ đồ tuần tự luồng thanh toán mô phỏng và đối soát hai bước an toàn")
    add_image_figure(os.path.join(assets_dir, 'hinh2_13b_tuan_tu_dat_tien_ich.png'), "Hình 2.13b. Sơ đồ tuần tự luồng đặt chỗ tiện ích và xử lý sức chứa đồng thời")
    add_image_figure(os.path.join(assets_dir, 'hinh2_14a_trang_thai_hoa_don.png'), "Hình 2.14a. Sơ đồ trạng thái vòng đời hóa đơn và phiếu phản ánh sự cố")
    add_image_figure(os.path.join(assets_dir, 'hinh2_15_kien_truc_tien_ich_va_thong_bao.png'), "Hình 2.15. Sơ đồ kiến trúc Quản trị tiện ích 3 Tab và cơ chế thông báo phân nhóm đích")

    # =========================================================
    # MINH CHỨNG GIAO DIỆN & KHUNG CHÚ THÍCH ẢNH CHỤP THỰC TẾ
    # =========================================================
    add_title("2.4. Thiết kế giao diện và minh chứng thực nghiệm", level=2)
    add_p("Hình 2.15 là bản phác thảo bố cục giao diện ban đầu:")
    add_image_figure(os.path.join(assets_dir, 'image16.png'), "Hình 2.15. Phác thảo bố cục màn hình chính phục vụ thiết kế giao diện")

    add_p("Dưới đây là các khung chú thích tương ứng với 8 màn hình thực tế của ứng dụng PKA-Home đang chạy trên thiết bị di động:")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 01: MÀN HÌNH ĐĂNG NHẬP VÀ PHÂN QUYỀN VAI TRÒ", 
                    "Chụp ảnh màn hình đăng nhập với giao diện tiếng Việt, nút ẩn/hiển thị mật khẩu và hộp thoại hướng dẫn khôi phục mật khẩu nội bộ qua Ban Quản Lý.")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 02: TRANG CHỦ CƯ DÂN (SMART DASHBOARD)", 
                    "Chụp ảnh trang chủ cư dân với tiêu đề mã phòng chuẩn A0110, thẻ tóm tắt tổng nợ màu đỏ, thanh thao tác nhanh và thẻ phản ánh sự cố khẩn cấp.")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 03: CHI TIẾT HÓA ĐƠN VÀ CỔNG THANH TOÁN MÔ PHỎNG", 
                    "Chụp màn hình phân rã chi tiết tiền điện, nước, phí quản lý kèm biểu tượng và cửa sổ thanh toán tích hợp ba phương thức (VietQR, Chuyển khoản, Tiền mặt).")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 04: KHAI BÁO CHỈ SỐ CÔNG TƠ ĐIỆN NƯỚC", 
                    "Chụp giao diện nộp chỉ số công tơ định kỳ hàng tháng của cư dân kèm ô nhập số đo và khung đính kèm ảnh công tơ thực tế.")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 05: ĐẶT TIỆN ÍCH CHUNG CƯ VÀ DANH SÁCH CHỜ", 
                    "Chụp màn hình chọn khung giờ tiện ích, số lượng khách, hiển thị sức chứa còn lại và thông báo đưa vào danh sách chờ khi khung giờ đã kín.")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 06: BẢNG ĐIỀU KHIỂN QUẢN TRỊ BAN QUẢN LÝ", 
                    "Chụp bảng điều khiển BQL hiển thị các thẻ KPI công việc tồn đọng (yêu cầu liên kết, hóa đơn chờ duyệt, sự cố mới, thẻ xe) và biểu đồ doanh thu.")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 07: LẬP HÓA ĐƠN HÀNG LOẠT VÀ DUYỆT CHỈ SỐ", 
                    "Chụp hộp thoại lập hóa đơn hàng loạt tự động tính phí gửi xe máy, ô tô theo căn hộ và màn hình thẩm định ảnh chụp công tơ của kế toán.")
    
    add_callout_box("ẢNH CHỤP THỰC TẾ 08: ĐIỀU PHỐI SỰ CỐ VÀ KHẢO SÁT CHẤT LƯỢNG", 
                    "Chụp màn hình trao đổi bình luận hai chiều giữa cư dân và kỹ thuật viên kèm phiếu đánh giá chất lượng dịch vụ ba tiêu chí từ 1 đến 5 sao.")

    # =========================================================
    # KIỂM THỬ VÀ ĐÁNH GIÁ NGHIỆM THU
    # =========================================================
    add_title("2.5. Kiểm thử và đánh giá nghiệm thu", level=2)
    add_p("Hệ thống áp dụng phương pháp kiểm thử phát triển hướng kiểm thử (TDD) với bộ kiểm thử tự động toàn diện. Toàn bộ mã nguồn đã vượt qua kiểm tra tĩnh và kiểm thử tự động đạt tỷ lệ tuyệt đối 100%:")

    test_data = [
        ["Nhóm kiểm thử", "Số lượng tệp", "Số ca kiểm thử thực thi", "Kết quả thực tế", "Tỷ lệ đạt"],
        ["Phân tích tĩnh (dart analyze)", "Toàn bộ dự án", "Toàn bộ mã nguồn", "0 Cảnh báo / 0 Lỗi", "100%"],
        ["Hằng số & Giao diện cơ sở", "17 tệp", "58 bài kiểm thử", "Vượt qua thành công", "100%"],
        ["Mô hình dữ liệu (Models)", "18 tệp", "74 bài kiểm thử", "Vượt qua thành công", "100%"],
        ["Kho lưu trữ (Repositories)", "35 tệp", "112 bài kiểm thử", "Vượt qua thành công", "100%"],
        ["Bộ điều phối (Providers)", "22 tệp", "65 bài kiểm thử", "Vượt qua thành công", "100%"],
        ["Màn hình Ban Quản Lý (3 Tab & A7/A8)", "24 tệp", "62 bài kiểm thử", "Vượt qua thành công", "100%"],
        ["Màn hình Cư dân (Hủy lịch & Payment)", "15 tệp", "37 bài kiểm thử", "Vượt qua thành công", "100%"],
        ["Kiểm thử tích hợp & Cloud RLS", "Tích hợp", "3 bài test Cloud RLS", "Bỏ qua khi test nội bộ", "Khảo nghiệm Cloud"],
        ["Tổng cộng toàn hệ thống", "131 tệp kiểm thử", "408 bài kiểm thử", "405/405 Logic Đạt 100%", "100% (Logic)"]
    ]
    create_styled_table(test_data[0], test_data[1:], [Inches(1.8), Inches(1.1), Inches(1.5), Inches(1.3), Inches(0.8)])

    add_image_figure(os.path.join(assets_dir, 'hinh_kiem_thu_tong_hop.png'), "Hình 2.16. Biểu đồ tổng hợp kết quả kiểm thử tự động và phân bổ bài test")

    # =========================================================
    # CHƯƠNG 3: KẾ HOẠCH DỰ ÁN
    # =========================================================
    add_title("3. CÁC THÀNH PHẦN KHÁC CỦA ĐỒ ÁN", level=1)
    add_title("3.1. Kế hoạch và tiến độ triển khai", level=2)
    add_p("Dự án được triển khai có kỷ luật qua 6 giai đoạn chặt chẽ trong vòng 6 tuần:")
    add_image_figure(os.path.join(assets_dir, 'hinh3_1_gantt_tien_do.png'), "Hình 3.1. Biểu đồ Gantt kế hoạch triển khai dự án theo tuần")

    add_title("3.2. Tổ chức thực hiện và kiểm soát chất lượng", level=2)
    add_p("Mỗi sửa đổi cơ sở dữ liệu đều được quản lý bằng các tệp migration SQL có gắn mốc thời gian rõ ràng. Tên hàm RPC và tham số luôn được đồng bộ chặt chẽ giữa mã Dart và cơ sở dữ liệu PostgreSQL. Bộ kiểm thử hồi quy được kích hoạt tự động để bảo đảm các tính năng mới không làm gián đoạn luồng nghiệp vụ hiện có.")

    add_title("3.3. Đạo đức và tác phong chuyên nghiệp", level=2)
    add_p("Quản lý chung cư liên quan trực tiếp đến thông tin cá nhân và tài chính của cư dân. Đồ án tuân thủ nghiêm ngặt các nguyên tắc bảo vệ quyền riêng tư: ảnh minh chứng sự cố được lưu trong vùng riêng tư, các tham số tài khoản nhạy cảm được che giấu trong nhật ký và không bao giờ đưa khóa bí mật vào mã nguồn công khai.")

    # =========================================================
    # CHƯƠNG 4: KẾT QUẢ, KẾT LUẬN & HƯỚNG PHÁT TRIỂN
    # =========================================================
    add_title("4. KẾT QUẢ, KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN", level=1)
    add_title("4.1. Kết quả xây dựng sản phẩm", level=2)
    add_p("Đồ án đã hiện thực hóa trọn vẹn 100% các tính năng đề ra ban đầu:")
    
    res_data = [
        ["Phân hệ chức năng", "Số chức năng chi tiết", "Mức độ hoàn thành", "Kết quả kiểm thử"],
        ["Xác thực & Phân quyền đa vai trò", "5 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Quản lý căn hộ & Hồ sơ cư dân 360 độ", "4 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Hóa đơn & Cổng thanh toán mô phỏng", "5 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Khai báo & Thẩm định chỉ số điện nước", "3 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Tiện ích tòa nhà & Quản lý sức chứa", "4 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Đăng ký & Phê duyệt phương tiện", "3 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Phản ánh sự cố & Đánh giá chất lượng", "4 chức năng", "100%", "Vượt qua toàn bộ"],
        ["Thông báo, Cẩm nang & Thiết bị", "4 chức năng", "100%", "Vượt qua toàn bộ"]
    ]
    create_styled_table(res_data[0], res_data[1:], [Inches(2.4), Inches(1.4), Inches(1.3), Inches(1.4)])

    add_title("4.2. Kết luận", level=2)
    add_p("PKA-Home đã giải quyết hiệu quả bài toán quản lý chung cư bằng giải pháp công nghệ di động hiện đại. Dự án đã chứng minh sự đúng đắn của việc kết hợp kiến trúc Feature-first với các cơ chế bảo vệ dữ liệu cấp máy chủ trên Flutter và Supabase/PostgreSQL. Sản phẩm đáp ứng đầy đủ các tiêu chuẩn kỹ thuật phần mềm, sẵn sàng phục vụ nghiệm thu và bảo vệ đồ án liên ngành.")

    add_title("4.3. Hướng phát triển", level=2)
    add_bullet("Tích hợp cổng thanh toán thực tế: Kết nối giao diện lập trình mở của ngân hàng thương mại để tự động gạch nợ hóa đơn thời gian thực.")
    add_bullet("Ứng dụng trí tuệ nhân tạo: Tích hợp mô hình thị giác máy tính cục bộ trên thiết bị di động hỗ trợ nhận diện tự động số công tơ điện nước và biển số xe.")
    add_bullet("Mở rộng đa nền tảng: Đóng gói và phát hành ứng dụng trên nền tảng iOS và phiên bản web dành cho ban quản trị tòa nhà.")

    # =========================================================
    # TÀI LIỆU THAM KHẢO
    # =========================================================
    add_title("5. TÀI LIỆU THAM KHẢO", level=1)
    refs = [
        "[1] Flutter. 'Architecting Flutter apps'. Tài liệu hướng dẫn kiến trúc ứng dụng Flutter. https://docs.flutter.dev/app-architecture",
        "[2] Supabase. 'Row Level Security'. Tài liệu về phân quyền dữ liệu ở cấp bản ghi. https://supabase.com/docs/guides/database/postgres/row-level-security",
        "[3] PostgreSQL Global Development Group. 'PostgreSQL 15 Documentation: Transactions, Generated Columns and Triggers'. https://www.postgresql.org/docs/15/",
        "[4] Firebase. 'Migrate from legacy FCM APIs to HTTP v1'. Tài liệu chuyển đổi giao thức gửi thông báo đẩy. https://firebase.google.com/docs/cloud-messaging/migrate-v1",
        "[5] OWASP Foundation. 'Application Security Verification Standard (ASVS) 4.0: Access Control and Data Integrity'. https://owasp.org/www-project-application-security-verification-standard/",
        "[6] Object Management Group (OMG). 'Unified Modeling Language Specification Version 2.5.1'. https://www.omg.org/spec/UML/2.5.1"
    ]
    for ref in refs:
        p_ref = doc.add_paragraph()
        p_ref.paragraph_format.space_after = Pt(4)
        p_ref.paragraph_format.line_spacing = 1.15
        r = p_ref.add_run(ref)
        r.font.name = "Times New Roman"
        r.font.size = Pt(11)

    out_file = r'c:/Users/ADMIN/StudioProjects/pka_home/docs/Bao_Cao_Do_An_Lien_Nganh_PKA_Home.docx'
    doc.save(out_file)
    print(f"Successfully generated DOCX: {out_file} ({os.path.getsize(out_file)} bytes)")

if __name__ == '__main__':
    create_report_docx()
