-- ============================================================================
-- MIGRATION: 20261127020000_eliminate_legacy_global_rls_policies.sql
-- Mục đích: Loại bỏ triệt để 30+ legacy global RLS policies còn tồn tại song
-- song với các policy cách ly đa tòa nhà trên Production, đảm bảo nguyên tắc
-- Tenant Isolation tuyệt đối (không để PostgreSQL gộp OR với policy toàn cục).
-- ============================================================================

-- ============================================================================
-- NHÓM A: GỠ CÁC LEGACY GLOBAL POLICIES TRÊN CÁC BẢNG ĐÃ CÓ TENANT POLICIES
-- ============================================================================

-- 1. apartments
DROP POLICY IF EXISTS "Management toàn quyền apartments" ON public.apartments;

-- 2. residents_apartments
DROP POLICY IF EXISTS "Management toàn quyền residents_apartments" ON public.residents_apartments;

-- 3. apartment_link_requests (giữ quyền DELETE cho BQL đúng tòa nhà)
DROP POLICY IF EXISTS "Admin toàn quyền trên yêu cầu liên kết" ON public.apartment_link_requests;
DROP POLICY IF EXISTS "Management toàn quyền apartment_link_requests" ON public.apartment_link_requests;
DROP POLICY IF EXISTS "link_requests_delete_admin" ON public.apartment_link_requests;
CREATE POLICY "link_requests_delete_admin"
ON public.apartment_link_requests
FOR DELETE
TO authenticated
USING (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = apartment_link_requests.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
    )
);

-- 4. invoices & invoice_items
DROP POLICY IF EXISTS "Admin và Accountant toàn quyền trên invoices" ON public.invoices;
DROP POLICY IF EXISTS "Management toàn quyền invoices" ON public.invoices;
DROP POLICY IF EXISTS "Admin và Accountant toàn quyền trên invoice_items" ON public.invoice_items;
DROP POLICY IF EXISTS "Management toàn quyền invoice_items" ON public.invoice_items;

-- 5. payment_transactions
DROP POLICY IF EXISTS "BQL quản lý giao dịch thanh toán" ON public.payment_transactions;
DROP POLICY IF EXISTS "Cư dân xem giao dịch căn hộ mình" ON public.payment_transactions;

-- 6. issue_reports & issue_images
DROP POLICY IF EXISTS "Admin và Kỹ thuật viên cập nhật issue_reports" ON public.issue_reports;
DROP POLICY IF EXISTS "Management toàn quyền issue_reports" ON public.issue_reports;
DROP POLICY IF EXISTS "Staff xem tất cả sự cố" ON public.issue_reports;

DROP POLICY IF EXISTS "Management toàn quyền issue_images" ON public.issue_images;
DROP POLICY IF EXISTS "Người liên quan xem issue_images" ON public.issue_images;
DROP POLICY IF EXISTS "Staff thêm issue_images" ON public.issue_images;
DROP POLICY IF EXISTS "issue_images_delete_admin" ON public.issue_images;
CREATE POLICY "issue_images_delete_admin"
ON public.issue_images
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        JOIN public.apartments a ON a.id = ir.apartment_id
        WHERE ir.id = issue_images.issue_report_id
          AND public.is_building_staff(a.building_id)
    )
);

-- 7. announcements, building_amenities, building_rules, emergency_contacts
DROP POLICY IF EXISTS "Management toàn quyền announcements" ON public.announcements;
DROP POLICY IF EXISTS "User đăng nhập xem announcements" ON public.announcements;

DROP POLICY IF EXISTS "Management toàn quyền building_amenities" ON public.building_amenities;
DROP POLICY IF EXISTS "Mọi user đăng nhập xem building_amenities" ON public.building_amenities;

DROP POLICY IF EXISTS "Management toàn quyền building_rules" ON public.building_rules;
DROP POLICY IF EXISTS "Mọi user đăng nhập xem building_rules" ON public.building_rules;

DROP POLICY IF EXISTS "Management toàn quyền emergency_contacts" ON public.emergency_contacts;
DROP POLICY IF EXISTS "Mọi user đăng nhập xem emergency_contacts" ON public.emergency_contacts;

-- 8. amenity_bookings (bổ sung quyền DELETE theo tòa nhà cho BQL)
DROP POLICY IF EXISTS "BQL xóa lịch tiện ích" ON public.amenity_bookings;
DROP POLICY IF EXISTS "Cư dân đặt lịch tiện ích" ON public.amenity_bookings;
DROP POLICY IF EXISTS "Mọi người xem lịch tiện ích" ON public.amenity_bookings;
DROP POLICY IF EXISTS "Người đặt hoặc BQL hủy lịch tiện ích" ON public.amenity_bookings;
DROP POLICY IF EXISTS "amenity_bookings_delete_admin" ON public.amenity_bookings;
CREATE POLICY "amenity_bookings_delete_admin"
ON public.amenity_bookings
FOR DELETE
TO authenticated
USING (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = amenity_bookings.apartment_id
        )
    )
);

-- 9. vehicles
DROP POLICY IF EXISTS "BQL toàn quyền quản lý xe" ON public.vehicles;
DROP POLICY IF EXISTS "Cư dân xem xe căn hộ mình" ON public.vehicles;
DROP POLICY IF EXISTS "Cư dân xóa xe căn hộ mình" ON public.vehicles;
DROP POLICY IF EXISTS "Cư dân đăng ký xe cho căn hộ mình" ON public.vehicles;

-- 10. audit_logs, notifications, role_delegations, user_fcm_tokens, users
DROP POLICY IF EXISTS "BQL xem audit_logs" ON public.audit_logs;

DROP POLICY IF EXISTS "Staff can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update read status" ON public.notifications;

DROP POLICY IF EXISTS "Admin toàn quyền trên role_delegations" ON public.role_delegations;

DROP POLICY IF EXISTS "Users can view own FCM tokens" ON public.user_fcm_tokens;

DROP POLICY IF EXISTS "Management toàn quyền users" ON public.users;
DROP POLICY IF EXISTS "Users có thể cập nhật thông tin của chính mình" ON public.users;

-- ============================================================================
-- NHÓM B: THAY THẾ CÁC POLICY CÒN DÙNG FROM users / TOÀN CỤC BẰNG TENANT SCOPE
-- ============================================================================

-- 11. amenity_maintenance_windows
DROP POLICY IF EXISTS "Ban quản lý quản trị lịch bảo trì" ON public.amenity_maintenance_windows;
DROP POLICY IF EXISTS "Mọi người xem lịch bảo trì tiện ích" ON public.amenity_maintenance_windows;
DROP POLICY IF EXISTS "maintenance_windows_write_admin" ON public.amenity_maintenance_windows;
DROP POLICY IF EXISTS "maintenance_windows_manage_tenant" ON public.amenity_maintenance_windows;
CREATE POLICY "maintenance_windows_manage_tenant"
ON public.amenity_maintenance_windows
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.building_amenities ba
        WHERE ba.id = amenity_maintenance_windows.amenity_id
          AND (
              public.is_super_admin()
              OR (
                  ba.building_id IS NOT NULL
                  AND public.is_building_staff(
                      ba.building_id,
                      ARRAY['admin', 'management', 'manager', 'owner', 'technician']
                  )
              )
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.building_amenities ba
        WHERE ba.id = amenity_maintenance_windows.amenity_id
          AND (
              public.is_super_admin()
              OR (
                  ba.building_id IS NOT NULL
                  AND public.is_building_staff(
                      ba.building_id,
                      ARRAY['admin', 'management', 'manager', 'owner', 'technician']
                  )
              )
          )
    )
);

-- 12. apartment_invitations
DROP POLICY IF EXISTS "invitations_select_policy" ON public.apartment_invitations;
DROP POLICY IF EXISTS "invitations_insert_policy" ON public.apartment_invitations;
DROP POLICY IF EXISTS "invitations_update_policy" ON public.apartment_invitations;

CREATE POLICY "invitations_select_policy"
ON public.apartment_invitations
FOR SELECT
TO authenticated
USING (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = apartment_invitations.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
    )
    OR EXISTS (
        SELECT 1
        FROM public.residents_apartments ra
        WHERE ra.apartment_id = apartment_invitations.apartment_id
          AND ra.user_id = auth.uid()
          AND ra.relation_role = 'owner'::public.relation_type
          AND COALESCE(ra.status, 'active') = 'active'
    )
);

CREATE POLICY "invitations_insert_policy"
ON public.apartment_invitations
FOR INSERT
TO authenticated
WITH CHECK (
    created_by = auth.uid()
    AND (
        public.is_building_staff(
            (
                SELECT a.building_id
                FROM public.apartments a
                WHERE a.id = apartment_invitations.apartment_id
            ),
            ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
        )
        OR EXISTS (
            SELECT 1
            FROM public.residents_apartments ra
            WHERE ra.apartment_id = apartment_invitations.apartment_id
              AND ra.user_id = auth.uid()
              AND ra.relation_role = 'owner'::public.relation_type
              AND COALESCE(ra.status, 'active') = 'active'
        )
    )
);

CREATE POLICY "invitations_update_policy"
ON public.apartment_invitations
FOR UPDATE
TO authenticated
USING (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = apartment_invitations.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
    )
    OR EXISTS (
        SELECT 1
        FROM public.residents_apartments ra
        WHERE ra.apartment_id = apartment_invitations.apartment_id
          AND ra.user_id = auth.uid()
          AND ra.relation_role = 'owner'::public.relation_type
          AND COALESCE(ra.status, 'active') = 'active'
    )
)
WITH CHECK (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = apartment_invitations.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
    )
    OR EXISTS (
        SELECT 1
        FROM public.residents_apartments ra
        WHERE ra.apartment_id = apartment_invitations.apartment_id
          AND ra.user_id = auth.uid()
          AND ra.relation_role = 'owner'::public.relation_type
          AND COALESCE(ra.status, 'active') = 'active'
    )
);

-- 13. debt_risk_scores & dunning_actions
DROP POLICY IF EXISTS "debt_risk_scores_staff_manage" ON public.debt_risk_scores;
CREATE POLICY "debt_risk_scores_staff_manage"
ON public.debt_risk_scores
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR public.is_building_staff(
        building_id,
        ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
    )
)
WITH CHECK (
    public.is_super_admin()
    OR public.is_building_staff(
        building_id,
        ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
    )
);

DROP POLICY IF EXISTS "dunning_actions_staff_manage" ON public.dunning_actions;
CREATE POLICY "dunning_actions_staff_manage"
ON public.dunning_actions
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR public.is_building_staff(
        building_id,
        ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
    )
)
WITH CHECK (
    public.is_super_admin()
    OR public.is_building_staff(
        building_id,
        ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
    )
);

-- 14. fee_tier_policies
DROP POLICY IF EXISTS "ftp_manage_policy" ON public.fee_tier_policies;
CREATE POLICY "ftp_manage_policy"
ON public.fee_tier_policies
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    )
);

-- 15. issue_comments
DROP POLICY IF EXISTS "residents_view_own_comments" ON public.issue_comments;
DROP POLICY IF EXISTS "users_insert_own_comments" ON public.issue_comments;

CREATE POLICY "residents_view_own_comments"
ON public.issue_comments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        WHERE ir.id = issue_comments.issue_report_id
          AND (
              ir.reporter_id = auth.uid()
              OR public.can_access_apartment(ir.apartment_id)
          )
    )
);

CREATE POLICY "users_insert_own_comments"
ON public.issue_comments
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        WHERE ir.id = issue_comments.issue_report_id
          AND (
              ir.reporter_id = auth.uid()
              OR public.can_access_apartment(ir.apartment_id)
          )
    )
);

-- 16. issue_materials
DROP POLICY IF EXISTS "Staff can insert issue materials" ON public.issue_materials;
DROP POLICY IF EXISTS "Users can read materials of their apartment issues" ON public.issue_materials;
DROP POLICY IF EXISTS "issue_materials_read_tenant" ON public.issue_materials;
DROP POLICY IF EXISTS "issue_materials_manage_tenant" ON public.issue_materials;

CREATE POLICY "issue_materials_read_tenant"
ON public.issue_materials
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        WHERE ir.id = issue_materials.issue_report_id
          AND (
              ir.reporter_id = auth.uid()
              OR public.can_access_apartment(ir.apartment_id)
          )
    )
);

CREATE POLICY "issue_materials_manage_tenant"
ON public.issue_materials
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        JOIN public.apartments a ON a.id = ir.apartment_id
        WHERE ir.id = issue_materials.issue_report_id
          AND public.is_building_staff(
              a.building_id,
              ARRAY['admin', 'management', 'manager', 'owner', 'technician']
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        JOIN public.apartments a ON a.id = ir.apartment_id
        WHERE ir.id = issue_materials.issue_report_id
          AND public.is_building_staff(
              a.building_id,
              ARRAY['admin', 'management', 'manager', 'owner', 'technician']
          )
    )
);

-- 17. maintenance_funds & maintenance_materials
DROP POLICY IF EXISTS "maintenance_funds_manage_admin" ON public.maintenance_funds;
DROP POLICY IF EXISTS "maintenance_funds_manage_tenant" ON public.maintenance_funds;
CREATE POLICY "maintenance_funds_manage_tenant"
ON public.maintenance_funds
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    )
);

DROP POLICY IF EXISTS "Management and technicians can manage materials" ON public.maintenance_materials;
DROP POLICY IF EXISTS "maintenance_materials_manage_tenant" ON public.maintenance_materials;
CREATE POLICY "maintenance_materials_manage_tenant"
ON public.maintenance_materials
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician']
        )
    )
);

-- 18. organization_subscriptions
DROP POLICY IF EXISTS "org_subscriptions_admin_update" ON public.organization_subscriptions;
CREATE POLICY "org_subscriptions_admin_update"
ON public.organization_subscriptions
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR EXISTS (
        SELECT 1
        FROM public.organization_memberships om
        WHERE om.organization_id = organization_subscriptions.organization_id
          AND om.user_id = auth.uid()
          AND om.is_active = true
          AND om.org_role::text IN ('org_owner', 'org_admin', 'owner', 'admin')
    )
)
WITH CHECK (
    public.is_super_admin()
    OR EXISTS (
        SELECT 1
        FROM public.organization_memberships om
        WHERE om.organization_id = organization_subscriptions.organization_id
          AND om.user_id = auth.uid()
          AND om.is_active = true
          AND om.org_role::text IN ('org_owner', 'org_admin', 'owner', 'admin')
    )
);

-- 19. parcels & visitor_access_passes
DROP POLICY IF EXISTS "Management and receptionists can manage all parcels" ON public.parcels;
CREATE POLICY "Management and receptionists can manage all parcels"
ON public.parcels
FOR ALL
TO authenticated
USING (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = parcels.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'security', 'receptionist']
    )
)
WITH CHECK (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = parcels.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'security', 'receptionist']
    )
);

DROP POLICY IF EXISTS "Management and guards can view and edit all visitor passes" ON public.visitor_access_passes;
CREATE POLICY "Management and guards can view and edit all visitor passes"
ON public.visitor_access_passes
FOR ALL
TO authenticated
USING (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = visitor_access_passes.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'security', 'receptionist']
    )
)
WITH CHECK (
    public.is_building_staff(
        (
            SELECT a.building_id
            FROM public.apartments a
            WHERE a.id = visitor_access_passes.apartment_id
        ),
        ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'security', 'receptionist']
    )
);

-- 20. parking_slots & visitor_parking_tickets
DROP POLICY IF EXISTS "parking_slots_manage_admin" ON public.parking_slots;
CREATE POLICY "parking_slots_manage_admin"
ON public.parking_slots
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'security', 'receptionist']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'security', 'receptionist']
        )
    )
);

DROP POLICY IF EXISTS "visitor_tickets_manage_admin" ON public.visitor_parking_tickets;
DROP POLICY IF EXISTS "visitor_tickets_read" ON public.visitor_parking_tickets;
CREATE POLICY "visitor_tickets_read"
ON public.visitor_parking_tickets
FOR SELECT
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'security', 'receptionist', 'staff']
        )
    )
);

CREATE POLICY "visitor_tickets_manage_admin"
ON public.visitor_parking_tickets
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'security', 'receptionist', 'staff']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'security', 'receptionist', 'staff']
        )
    )
);

-- 21. polls, poll_options, poll_votes, resident_petitions, resident_activations
DROP POLICY IF EXISTS "Management can manage polls" ON public.polls;
CREATE POLICY "Management can manage polls"
ON public.polls
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner']
        )
    )
);

DROP POLICY IF EXISTS "Management can manage poll options" ON public.poll_options;
CREATE POLICY "Management can manage poll options"
ON public.poll_options
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.polls p
        WHERE p.id = poll_options.poll_id
          AND (
              public.is_super_admin()
              OR (
                  p.building_id IS NOT NULL
                  AND public.is_building_staff(
                      p.building_id,
                      ARRAY['admin', 'management', 'manager', 'owner']
                  )
              )
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.polls p
        WHERE p.id = poll_options.poll_id
          AND (
              public.is_super_admin()
              OR (
                  p.building_id IS NOT NULL
                  AND public.is_building_staff(
                      p.building_id,
                      ARRAY['admin', 'management', 'manager', 'owner']
                  )
              )
          )
    )
);

DROP POLICY IF EXISTS "Residents view own apartment votes" ON public.poll_votes;
CREATE POLICY "Residents view own apartment votes"
ON public.poll_votes
FOR SELECT
TO authenticated
USING (public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "Management can update petitions" ON public.resident_petitions;
CREATE POLICY "Management can update petitions"
ON public.resident_petitions
FOR UPDATE
TO authenticated
USING (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner']
        )
    )
    OR (
        apartment_id IS NOT NULL
        AND public.is_building_staff(
            (
                SELECT a.building_id
                FROM public.apartments a
                WHERE a.id = resident_petitions.apartment_id
            ),
            ARRAY['admin', 'management', 'manager', 'owner']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        building_id IS NOT NULL
        AND public.is_building_staff(
            building_id,
            ARRAY['admin', 'management', 'manager', 'owner']
        )
    )
    OR (
        apartment_id IS NOT NULL
        AND public.is_building_staff(
            (
                SELECT a.building_id
                FROM public.apartments a
                WHERE a.id = resident_petitions.apartment_id
            ),
            ARRAY['admin', 'management', 'manager', 'owner']
        )
    )
);

DROP POLICY IF EXISTS "Management and admin can manage resident activations" ON public.resident_activations;
CREATE POLICY "Management and admin can manage resident activations"
ON public.resident_activations
FOR ALL
TO authenticated
USING (
    public.is_super_admin()
    OR (
        apartment_id IS NOT NULL
        AND public.is_building_staff(
            (
                SELECT a.building_id
                FROM public.apartments a
                WHERE a.id = resident_activations.apartment_id
            ),
            ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
        )
    )
)
WITH CHECK (
    public.is_super_admin()
    OR (
        apartment_id IS NOT NULL
        AND public.is_building_staff(
            (
                SELECT a.building_id
                FROM public.apartments a
                WHERE a.id = resident_activations.apartment_id
            ),
            ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']
        )
    )
);
