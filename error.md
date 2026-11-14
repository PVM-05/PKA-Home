Tôi đã đọc ~50 màn hình. Chưa thấy: widget con (sheet/dialog), provider/repository bản mới, SQL, test/. Những chỗ tôi chỉ suy đoán sẽ ghi “cần xác minh”.

Tình hình chung: UI phong phú và nhất quán hơn trước, nhưng phía management có nhiều chỗ ghi sai dữ liệu hoặc làm hành động nhạy cảm chỉ bằng một lần bấm. Đây là phần nguy hiểm nhất khi triển khai thật.

1. P0: sai dữ liệu, sai tiền, hành động nguy hiểm
#	Vị trí	Lỗi	Hậu quả / cách sửa
1	handover_management_screen → _showCreateHandoverDialog	Nhập mã căn nhưng luôn truyền apartmentId: 'apt-01', buildingId mặc định 'bld-01'	Biên bản gắn sai căn hộ. Chọn căn từ danh sách thật (có tìm kiếm), truyền id thật
2	inspection_workstation_screen	Chỉ số điện 1540.0, nước 85.0, cọc 10.000.000 điền sẵn; conductedBy: 'staff-01'; reportCode luôn HO-YYYYMM-0001; id sinh ở client	Nhân viên quên sửa là ký xác nhận số liệu sai. Để trống, bắt buộc nhập; lấy auth.uid(), mã biên bản và id do server sinh
3	Cùng màn	“Mở trạm kiểm kê” mở được biên bản đã confirmed, lưu lại sẽ đặt pending_resident	Sửa được văn bản hai bên đã ký. Biên bản đã ký là bất biến. Muốn chỉnh thì tạo biên bản bổ sung
4	Cùng màn	_totalDeduction cộng repairCost của mọi hạng mục, kể cả hạng mục đã đổi lại “Tốt”	Trừ cọc sai. Chỉ cộng khi hasDamage, xóa repairCost khi đổi tình trạng
5	Cùng màn	createHandover rồi signByStaff là hai lệnh riêng	Lỗi giữa chừng để lại dữ liệu lửng. Gộp thành một RPC nguyên tử
6	parking_management_screen → _showAssignSlotDialog	vehicleId: 'veh-${slot.id}', apartmentId: 'apt-${slot.id}'	Ghi ID giả vào DB. Chọn xe đã duyệt từ danh sách thật
7	equipment_detail_screen → _disburseMaintenanceFund	buildingId = activeBuilding?.id ?? _equipment.building (tên “Tòa A” bị dùng làm id); nút “Chi từ Quỹ” hiện vĩnh viễn trên mọi task hoàn thành	Chi hai lần cho một phiếu, sai quỹ. Thêm disbursed_voucher_id vào task, ẩn nút sau khi chi, unique (reference_type, reference_id), duyệt chi nhiều cấp khi vượt hạn mức
8	edit_invoice_screen	(a) Dropdown đổi thẳng sang paid mà không có giao dịch thu; (b) fee_type bị ghi đè bằng tên hiển thị (“Tiền điện”) thay vì khóa (electricity)	(a) Qua sổ cái. Hóa đơn đã phát hành/đã thu thì khóa, sửa = phiếu điều chỉnh. (b) Hỏng nhận diện bậc thang, báo cáo theo loại phí
9	invoice_management_screen, management_invoice_detail_screen	Xóa được hóa đơn paid chỉ với một hộp thoại	Mất lịch sử kế toán. Chỉ xóa nháp, còn lại hủy bằng credit note
10	create_invoice_screen	Tiền điện = kWh × đơn giá phẳng (3500), nhưng phía cư dân tính lại bậc thang EVN	Hai bên hiển thị số khác nhau. Một engine ở server tính, client chỉ hiển thị. Đơn giá mặc định 16500/3500/18000 hardcode cũng phải đọc từ fee_schedules
11	create_invoice_screen	Tạo xong hóa đơn hiện ngay cho cư dân	Thêm trạng thái draft, BQL xem trước và “Phát hành” (xem mục 4)
12	accounting_web_workstation_screen	“Gửi Nhắc Nợ” chỉ hiện SnackBar “Đã gửi thông báo…”; “Khớp nợ thủ công” chỉ hiện SnackBar; sort bảng không hoạt động (_sortColumnIndex final, cột không có onSort)	Báo thành công giả. Nối vào RPC thật hoặc ẩn nút. Quy tắc: không bao giờ hiện thông báo thành công nếu chưa có phản hồi server
13	announcement_management_screen	Nút AppBar “Quét nhắc nợ” gửi cho toàn bộ người nợ không xác nhận; autoBroadcast mặc định bật; “phát lại” cũng không xác nhận	Gửi nhầm cho hàng trăm người. Hộp thoại xác nhận có số người nhận, hẹn giờ, giới hạn tần suất phát lại
14	role_delegation_screen	Danh sách người nhận gồm cả cư dân (role != admin/management)	Cấp quyền kế toán cho cư dân. Chỉ cho nhân viên; chặn chồng lấn ủy quyền; thông báo người nhận
15	amenity_management_screen	(a) reasonController của “Từ chối/Hủy” không được gửi đi; (b) check-in: lỗi checkInTicket bất kỳ đều rơi sang checkInBooking (có thể bypass vé); (c) nút “Check-in” ở thẻ không try/catch; (d) dropdown cho đổi trạng thái cọc sang refunded tự do mà không có giao dịch	(a) Cư dân không biết lý do, không hoàn phí. (d) Cọc chỉ đổi qua nghiệm thu/giao dịch. Cọc là khoản phải trả, không tính vào doanh thu như totalFee = fee + deposit hiện tại
16	resident_meter_reading_screen	Gửi electricImageUrl: _electricImagePath (đường dẫn file cục bộ); averageUsage hardcode 130.0 / 12.0 cho mọi căn	Cần xác minh repository có upload không; nếu không, BQL không bao giờ thấy ảnh. Mức trung bình phải tính từ 3–6 kỳ của chính căn đó. Kỳ khai báo gõ tay tự do, cần khóa kỳ hiện tại
17	management_meter_reading_screen	Duyệt chỉ số có cảnh báo danger chỉ cần một lần bấm; mặc định tạo hóa đơn luôn; ngày hạn cố định +10 ngày dù dialog có vẻ cho chọn; ước tính dùng 3500*1.08	Bắt buộc nhập lý do hoặc chụp lại khi danger; cho chọn hạn; lấy ước tính từ server
18	Nhiều màn (maintenance_fund_ledger, materials, create_invoice, handover…)	double.tryParse(text) với tiền nhập kiểu 1.500.000 hoặc 50.000	Parse ra 1.5 hoặc 50.0 hoặc null→0. Lỗi âm thầm, sai tiền. Dùng MoneyInputFormatter (mã mẫu ở mục 5), lưu int đồng
19	Nhiều màn management	Không có RoleGuard: parking, community, handover + inspection, materials, maintenance_fund_ledger, financial_report, apartment_ledger (có “Khóa sổ kỳ”), fee_policy, subscription, batch_import, permission_matrix, equipment_detail, accounting_workstation	Kỹ thuật viên vào được qua URL/deep link. Dựng map route → permission trong redirect của router (mã mẫu ở mục 5)
20	resident_management_screen	Tạo user: hiển thị mật khẩu ngẫu nhiên để admin “sao chép gửi người dùng”; admin tạo được role admin không cần xác nhận	Thay bằng invite link; tạo admin cần xác nhận lại mật khẩu/MFA
21	link_request_management_screen	user['full_name'] crash nếu users null; từ chối không có lý do; duyệt/từ chối không xác nhận; không cảnh báo khi căn đã có chủ hộ	Hiển thị SĐT, thời gian, minh chứng; bắt buộc lý do khi từ chối; cảnh báo xung đột owner
22	materials_screen	updateMaterialStock(stock + qty) đọc-sửa-ghi ở client; id/mã sinh ở client; không try/catch	Hai người nhập cùng lúc bị mất cập nhật. RPC adjust_stock(delta, reason) + bảng stock_movements
23	fee_policy_management_screen	Khi RPC lỗi/rỗng, hiển thị _defaultPolicies hardcode như thể đã cấu hình; không có UI sửa biểu giá	Admin không đổi được giá. Đây là màn bắt buộc phải có (CRUD + ngày hiệu lực + xem trước ảnh hưởng)
2. P1: bug chức năng
FAB không đổi khi chuyển tab: community_management, resident_community, resident_visitor_parcel, equipment_management đọc _tabController.index trong build mà không addListener. Ví dụ ở resident_community, nút “Gửi kiến nghị” không xuất hiện khi sang tab 2. Thêm _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() {}); }) (như vehicle_approval đã làm).
create_issue_screen: nút xóa ảnh là Padding không có Icon, nên người dùng không thấy và không xóa được ảnh. Ảnh chưa nén kích thước (maxWidth), có thể 8–12 MB mỗi ảnh trên 4G.
resident_invoice_detail_screen: _showTieredBreakdownDialog được gọi không truyền item, nên nhánh “đọc breakdown đã lưu” không bao giờ chạy; luôn tính lại ở client.
issue_detail_screen: timeline dùng issue.updatedAt cho cả “Đang xử lý” và “Đã giải quyết”, nên giờ sai. Cần bảng issue_status_history.
payment_history_screen: giao dịch PENDING/UNMATCHED hiển thị icon lỗi đỏ giống thất bại.
issue_management_screen: nếu tải danh sách nhân viên lỗi, catch âm thầm chuyển sang “Đang xử lý” không có người phụ trách. Thiếu: đổi mức ưu tiên, hủy/từ chối, mở lại, gộp sự cố trùng.
management_home_screen:
Khối “việc cần xử lý” phụ thuộc allIssuesAsync. Issue lỗi hoặc bị RLS chặn (kế toán) thì cả khối báo “Lỗi tải dữ liệu”, ẩn luôn hóa đơn chờ đối soát.
Toast và push realtime gửi cho mọi role (kỹ thuật viên nhận toast “Cư dân gửi xác nhận chuyển khoản”). Lọc theo permission.
Tiêu đề “Công việc cần xử lý ngay • Phản ánh cần xử lý gấp” lẫn hai ý.
IndexedStack dựng sẵn tất cả tab (cư dân, hóa đơn, đối soát, sự cố, thông báo) lúc mở app, mỗi tab watch stream riêng. Dựng lazy theo tab đã mở.
Quick action trùng: “Báo cáo TC” / “Bàn kế toán” / tab “Đối soát”; “Bãi xe”, “Lễ tân”, “Cộng đồng”, “Bàn giao” hiện cho mọi role.
Đăng xuất xuất hiện 3 chỗ (menu, icon AppBar, sidebar).
_showAllQuickActionsSheet nhận 15 tham số bool: gom vào một ManagementCapabilities.
financial_report_screen: danh sách kỳ hardcode [10,9,8,7,6]/2026. Kỳ hiện tại (11/2026) không có, sang 2027 hỏng hoàn toàn. riskScore = overdueDays*2 là điểm giả. Xô “0–30 ngày” trộn “chưa đến hạn” với “quá hạn”, sai chuẩn tuổi nợ.
audit_trail_screen: mọi truy vấn catch (_) {} nên lỗi hiện thành “Chưa có hoạt động” (nhật ký kiểm toán không được im lặng). Mỗi nguồn limit(10); bộ lọc “Của tôi” không bao giờ khớp hóa đơn/liên kết (changedBy == null). Truy vấn nằm trong file UI. Thiếu tìm kiếm, khoảng ngày, xem before/after, xuất file.
apartment_management_screen: gọi SupabaseConfig.client trực tiếp trong FutureBuilder ở UI. Chỉ chặn xóa bằng cờ isEmpty; căn có hóa đơn/lịch sử vẫn hard-delete. Chuyển sang lưu trữ (archived_at).
Resident amenity: pending_payment không giữ chỗ và không hết hạn (hai người cùng chờ thanh toán một slot); QR PKA-TICKET:token:căn:slot không ký, token suy từ id. Lưu ý quản lý check-in cũng parse chuỗi này.
resident_profile_screen: hiển thị tên và SĐT của mọi thành viên cùng căn cho tất cả (kể cả người thuê). Chỉ hiện tên, ẩn SĐT trừ chủ hộ. Vẫn thiếu “Xóa tài khoản” (bắt buộc cho App Store/Google Play).
resident_vehicle: hạn mức 2 xe máy chỉ đếm xe isActive, nên đăng ký nhiều xe pending vượt hạn mức. Không có xe đạp điện dù model hỗ trợ. Biển số chỉ kiểm độ dài 4–15 ký tự.
resident_meter_reading: chặn số mới < số cũ mà không có luồng thay công tơ/quay vòng.
notification_center_screen: chỉ điều hướng với invoice_* và issue_update. Thông báo bưu kiện, khách, thông báo BQL, duyệt liên kết bấm vào không có gì xảy ra. Không phân trang, không gom theo ngày.
resident_handbook_screen: tìm kiếm khớp contactType (mã tiếng Anh) thay vì nhãn hiển thị. Tab biểu phí đọc AppConstants hardcode, không theo tòa.
Trùng nhau: hai màn cùng sửa bảng amenity (AmenityManagement mặc định slot 90 phút, HandbookManagement mặc định 60); biên nhận tiện ích copy ở hai nơi; _showThemeModeSheet giống hệt _showManagementThemeModeSheet.
Không phân biệt được “kiểm tra lại”: resident_handover_detail dùng depositRefundCalculated (tính ở client) trong khi BQL lưu depositRefund, có thể lệch nhau. Chỉ hiển thị số đã lưu.
Bàn giao phía BQL không có chỗ xử lý khiếu nại: cư dân có thể disputed, nhưng bộ lọc chỉ có “Chờ ký/Đã xác nhận”, không có thao tác phản hồi/giải quyết.
3. Các lỗi lặp lại ở nhiều màn (sửa một lần, hưởng khắp nơi)
Controller không dispose trong hầu hết hộp thoại (showDialog + TextEditingController tạo trong hàm: amenity, handbook, resident_management, announcement, materials, role_delegation, fund ledger…). Chuyển mỗi hộp thoại thành StatefulWidget riêng sở hữu controller (mục 5).
Lọc/tìm kiếm/sắp xếp ở client trên toàn bộ danh sách (hóa đơn, cư dân, sự cố, giao dịch, khách, bưu kiện). DataTable dựng hết dòng nên chậm từ ~200 dòng. Dùng phân trang server + PaginatedDataTable hoặc data_table_2; truyền filter xuống RPC.
Truy vấn Supabase ngay trong widget (audit_trail, apartment_management) và dùng Map<String,dynamic>/dynamic trong UI (currentUser: dynamic, AsyncValue<dynamic>). Đưa vào repository, dùng DTO có kiểu.
Kích thước cố định mà không tính cỡ chữ: mainAxisExtent: 290 (vehicle approval), 145/155 (ô đỗ), childAspectRatio (quick action, KPI), SliverAppBar expandedHeight: 140. Với text scale tới 1.69 sẽ tràn. Dùng mainAxisExtent theo MediaQuery.textScalerOf hoặc layout tự co giãn, và clamp scale ≤ 1.3 trong test.
Màu cứng Colors.white, Colors.grey.shadeX (tiện ích, đối soát, cộng đồng, ủy quyền, bottom sheet) vỡ dark mode.
Scaffold lồng nhau (tab con có AppBar/FAB riêng trong AdaptiveManagementScaffold) gây hai thanh tiêu đề, FAB chồng. Tab con nên trả về nội dung thuần, hoặc đặt FAB một nơi.
Chuỗi lỗi lộ ra: 'Lỗi: $e' ở community, visitor, meter, parking (Lỗi: $err). Qua formatErrorMessage/AppErrorCard.
Hành động không có phản hồi lỗi (parking check-in/out, front desk check-out, materials, amenity check-in, subscription.requestPlanUpgrade kể cả nhánh thành công giả). Một wrapper runAction(context, () async {...}) xử lý loading, lỗi, thành công, ghi log.
Widget deprecated: RadioListTile.groupValue/onChanged; thay bằng RadioGroup (Flutter mới) hoặc SegmentedButton.
4. Cải tiến UI/UX theo vai trò
BQL: Trang tổng quan
Dashboard theo vai trò: admin thấy tài chính và duyệt; kế toán thấy thu/nợ/đối soát; kỹ thuật viên thấy “việc của tôi” (sự cố được giao, thiết bị đến hạn, SLA sắp trễ). Hiện cả ba nhận cùng một lưới 15 lối tắt.
Đầu trang là hàng đợi công việc có số đếm và SLA (chờ đối soát, chờ duyệt liên kết, chờ duyệt chỉ số, sự cố khẩn), mỗi dòng bấm vào thẳng danh sách đã lọc. Bỏ lưới lối tắt, thay bằng sidebar có nhóm (Cư dân, Tài chính, Vận hành, Hệ thống) và Cmd/Ctrl+K tìm nhanh căn/cư dân/hóa đơn.
Ô KPI có so sánh kỳ trước và bấm xem chi tiết; chọn tòa nhà ở một nơi, áp dụng toàn bộ.
BQL: Hóa đơn và đối soát
Vòng đời: draft → approved → published → partially_paid → paid → void. Lập hàng loạt (đã có BulkInvoiceDialog) ra bản nháp, có màn rà soát (chênh lệch so với kỳ trước >30%, thiếu chỉ số, diện tích 0), rồi “Phát hành” một lần.
Ô nhập “Số tiền thực nhận” khi xác nhận thu (hỗ trợ trả thiếu/thừa), số biên lai, đính kèm ảnh chứng từ.
Bảng đối soát: phân trang, cột tùy chỉnh, lọc lưu được, sort thật, chọn nhiều → hành động hàng loạt có xác nhận và kết quả từng dòng. Giao dịch chưa khớp: gợi ý hóa đơn theo số tiền + nội dung + căn.
Tab SePay: hiển thị lý do chưa khớp (sai số tiền, sai mã, trùng) và hàng đợi cần xử lý.
BQL: Sự cố
Bảng Kanban (Mới → Đã giao → Đang xử lý → Chờ nghiệm thu → Xong) kéo thả trên web; trên mobile giữ danh sách.
Chi tiết: đổi ưu tiên, giao lại, ghi chú nội bộ (cư dân không thấy), ảnh trước/sau, vật tư và chi phí gắn sự cố, hẹn giờ.
Hàng đợi riêng cho sự cố hazardous kèm âm báo và gọi trực ban.
BQL: Cư dân và căn hộ
Gán căn: tìm kiếm, chọn vai trò, ngày bắt đầu/kết thúc, chặn gán nhiều chủ hộ không cố ý, giữ lịch sử.
Hồ sơ 360 có tab: Căn hộ, Hóa đơn, Xe, Sự cố, Hợp đồng, Nhật ký đăng nhập; nút khóa/mở khóa, đăng xuất mọi thiết bị, gửi lại link kích hoạt.
Import có dry-run, lịch sử lần nhập, tải file lỗi (batch_import_center đã gần đúng, thiếu lịch sử và hoàn tác).
BQL: Bàn giao, bãi xe, lễ tân
Bàn giao: wizard 4 bước (Chốt công tơ có ảnh → Kiểm kê từng hạng mục có ảnh → Tính cọc/công nợ → Ký). Cho phép tạo hóa đơn cuối kỳ và lệnh hoàn cọc ngay.
Bãi xe: xác nhận khi “Giải phóng” (hiện là chữ 11px một chạm), hiển thị sơ đồ theo tầng, ghi nhận tiền mặt vào ca thu ngân; “Quét VietQR” thật sự hiện mã và chờ xác nhận.
Lễ tân: dùng mobile_scanner quét thật (nút “Quét vé” hiện là ô nhập chữ). Sau khi quét hiện thẻ khách (tên, căn đến, mục đích, biển số, ảnh) và nút “Gọi chủ hộ”, “Từ chối”. Chỉ tải khách hôm nay + đang trong tòa, không tải toàn bộ lịch sử. Cần role security/receptionist riêng (hiện dùng chung residentManagement).
BQL: Thông báo

Soạn → xem trước → chọn đối tượng (đếm người nhận) → hẹn giờ hoặc gửi → theo dõi tỷ lệ đã nhận/đã đọc. Mẫu soạn sẵn (cúp điện, bảo trì thang, họp cư dân), đính kèm ảnh/PDF, nhắc lại cho người chưa đọc thay vì phát lại toàn bộ.

Cư dân
Trang chủ: hàng “việc cần làm” (hóa đơn đến hạn, bưu kiện chờ nhận kèm PIN, hạn chốt số, khách sắp đến, biểu quyết sắp đóng); thu gọn thẻ “Tổng quan hóa đơn” khi nợ bằng 0; bỏ nút đăng xuất ở header trang chủ (dễ bấm nhầm).
Điều hướng: 5 tab (Trang chủ, Hóa đơn, Dịch vụ, Hỗ trợ, Tôi); 8+ dịch vụ gom thành lưới ở tab Dịch vụ.
Chỉ số điện nước: chụp ảnh là bước đầu tiên, ML Kit đọc số và điền sẵn để người dùng xác nhận, hiển thị so sánh “tháng trước X, mức dùng Y, trung bình Z”. Chỉ cho nhập kỳ đang mở.
Sự cố: wizard 3 bước, nút xóa ảnh có thể thấy, nén ảnh, gửi nháp khi mất sóng, hiển thị ETA kỹ thuật viên.
Tiện ích: hiển thị chính sách hủy/hoàn tiền ngay lúc đặt, đếm ngược giữ chỗ khi chờ thanh toán, QR ký số.
Hóa đơn: so sánh kỳ trước, biểu đồ 12 tháng, “Khiếu nại khoản phí này”, chọn nhiều hóa đơn để thanh toán một lần, nút “Mở app ngân hàng” và “Lưu QR”.
Hồ sơ: xóa tài khoản, xuất dữ liệu, thiết bị đăng nhập, giờ yên tĩnh cho thông báo, sinh trắc học, phiên bản app và liên hệ hỗ trợ.
5. Mã mẫu cho các lỗi lặp lại

a) Quyền theo route (chặn deep link)

dart
final _routePermissions = <String, PermissionItem>{
  AppRoutes.managementParking: AppPermissions.parkingManagement,
  AppRoutes.managementFinancialReport: AppPermissions.financialReport,
  AppRoutes.managementMaterials: AppPermissions.issueManagement,
  AppRoutes.managementSubscription: AppPermissions.subscription,
  // ... mọi route /management/*
};

redirect: (context, state) {
  final user = ref.read(authProvider).valueOrNull;
  final perm = _routePermissions.entries
      .firstWhereOrNull((e) => state.matchedLocation.startsWith(e.key))?.value;
  if (perm != null && !perm.allows(user?.role, activeDelegations: ref.read(activeDelegationsProvider).valueOrNull ?? [])) {
    return AppRoutes.managementHome;
  }
  return null;
}

Đây chỉ là lớp UI; quyền thật vẫn ở RLS/RPC.

b) Hộp thoại sở hữu controller (hết rò rỉ)

dart
class RejectBookingDialog extends StatefulWidget {
  const RejectBookingDialog({super.key});
  @override State<RejectBookingDialog> createState() => _State();
}
class _State extends State<RejectBookingDialog> {
  final _reason = TextEditingController();
  @override void dispose() { _reason.dispose(); super.dispose(); }
  @override Widget build(BuildContext c) => AlertDialog(
    content: TextField(controller: _reason),
    actions: [FilledButton(onPressed: () => Navigator.pop(c, _reason.text.trim()), child: const Text('Xác nhận'))],
  );
}
// dùng: final reason = await showDialog<String>(context: context, builder: (_) => const RejectBookingDialog());

c) Nhập tiền đúng định dạng Việt Nam

dart
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final digits = n.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return n.copyWith(text: '');
    final text = NumberFormat('#,###', 'vi_VN').format(int.parse(digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
int parseMoney(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

d) Hành động có phản hồi trung thực

dart
Future<void> runAction(BuildContext ctx, Future<String?> Function() action) async {
  try {
    final msg = await action();                 // chỉ báo thành công khi server trả OK
    if (ctx.mounted && msg != null) _toast(ctx, msg, ok: true);
  } catch (e, st) {
    AppLogger.e('action failed', e, st);
    if (ctx.mounted) _toast(ctx, formatErrorMessage(e), ok: false);
  }
}

e) Tab + FAB

dart
_tabController = TabController(length: 2, vsync: this)
  ..addListener(() { if (!_tabController.indexIsChanging && mounted) setState(() {}); });
6. Tính năng còn thiếu để giống sản phẩm thật
Nhóm	Hạng mục
Tài chính	Draft/approve/publish hóa đơn; credit note; số dư/credit cư dân; thu thiếu/thừa; đóng kỳ có kiểm soát; duyệt chi nhiều cấp cho quỹ bảo trì; sổ thu chi tiền mặt theo ca; đối soát cuối ngày
Biểu giá	Màn CRUD biểu giá có ngày hiệu lực; engine tính một nơi (server); lãi phạt tự động
Tài khoản	Invite link; xác minh SĐT; ngày hiệu lực liên kết căn; tạo role tùy chỉnh (hiện read-only trong Permission Matrix); MFA nối vào đăng nhập; đăng xuất từ xa
Vận hành	Lịch trực/ca; tuần tra QR; nhà thầu; bảo trì định kỳ có checklist + QR thiết bị; đính kèm hóa đơn/ảnh vào phiếu bảo trì; thay công tơ
Cư dân	Hộp thư hai chiều với BQL; đăng ký thi công nội thất; SOS; kho tài liệu (biên bản, hợp đồng); đăng ký cho thuê; trả góp công nợ
Pháp lý	Biểu quyết chính thức chỉ cho owner, xuất biên bản kiểm phiếu, khóa kết quả; xóa/xuất dữ liệu cá nhân
Hệ thống	Xuất báo cáo định kỳ tự động; nhật ký kiểm toán chuẩn (một bảng, before/after, IP); giám sát (Sentry); test RLS/RPC