-- ==============================================================================
-- PKA-HOME: SEED DATA MẪU TOÀN DIỆN CHO TOÀN BỘ HỆ THỐNG
-- Phục vụ trình diễn, kiểm thử đồ án tốt nghiệp
-- Mật khẩu chung cho tất cả tài khoản: PkaHome@2026
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. TẠO 150 CĂN HỘ (3 TÒA A, B, C; TẦNG 1-10; PHÒNG 01-05)
INSERT INTO public.apartments (code, building_code, floor_number, area, is_empty)
SELECT 
    b.building || lpad(f.floor::text, 2, '0') || lpad(r.room::text, 2, '0') AS code,
    b.building AS building_code,
    f.floor AS floor_number,
    ROUND((60.0 + (random() * 40.0))::numeric, 1) AS area,
    true AS is_empty
FROM 
    unnest(ARRAY['A', 'B', 'C']) AS b(building),
    generate_series(1, 10) AS f(floor),
    generate_series(1, 5) AS r(room)
ON CONFLICT (code) DO NOTHING;

-- 2. SEED TÀI KHOẢN BQL & CƯ DÂN (@gmail.com / PkaHome@2026)
DO $$
BEGIN

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0101@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'edc08186-8cd1-4b53-9e6c-55d0d9922276', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0101@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Phạm Minh Đức', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'edc08186-8cd1-4b53-9e6c-55d0d9922276', 'edc08186-8cd1-4b53-9e6c-55d0d9922276', jsonb_build_object('sub', 'edc08186-8cd1-4b53-9e6c-55d0d9922276', 'email', 'cudan.a0101@gmail.com'),
            'email', 'edc08186-8cd1-4b53-9e6c-55d0d9922276', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('edc08186-8cd1-4b53-9e6c-55d0d9922276', 'Phạm Minh Đức', '0911001001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0102@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '07ad14a4-1af5-4a08-ab25-a4db4354a106', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0102@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Vũ Tuấn Anh', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '07ad14a4-1af5-4a08-ab25-a4db4354a106', '07ad14a4-1af5-4a08-ab25-a4db4354a106', jsonb_build_object('sub', '07ad14a4-1af5-4a08-ab25-a4db4354a106', 'email', 'cudan.a0102@gmail.com'),
            'email', '07ad14a4-1af5-4a08-ab25-a4db4354a106', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('07ad14a4-1af5-4a08-ab25-a4db4354a106', 'Vũ Tuấn Anh', '0911001003', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0103@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '4a231008-4b9b-4946-86a8-6d041ce67812', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0103@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Đặng Văn Dũng', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '4a231008-4b9b-4946-86a8-6d041ce67812', '4a231008-4b9b-4946-86a8-6d041ce67812', jsonb_build_object('sub', '4a231008-4b9b-4946-86a8-6d041ce67812', 'email', 'cudan.a0103@gmail.com'),
            'email', '4a231008-4b9b-4946-86a8-6d041ce67812', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('4a231008-4b9b-4946-86a8-6d041ce67812', 'Đặng Văn Dũng', '0911001004', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0201@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0201@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Bùi Thanh Hằng', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', '65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', jsonb_build_object('sub', '65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', 'email', 'cudan.a0201@gmail.com'),
            'email', '65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', 'Bùi Thanh Hằng', '0911002001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0202@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '83127e15-3c5c-48ea-99ef-c0666230b225', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0202@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Trịnh Đình Trọng', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '83127e15-3c5c-48ea-99ef-c0666230b225', '83127e15-3c5c-48ea-99ef-c0666230b225', jsonb_build_object('sub', '83127e15-3c5c-48ea-99ef-c0666230b225', 'email', 'cudan.a0202@gmail.com'),
            'email', '83127e15-3c5c-48ea-99ef-c0666230b225', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('83127e15-3c5c-48ea-99ef-c0666230b225', 'Trịnh Đình Trọng', '0911002002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0203@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '72056029-3a7a-4729-b821-c5e34737aa3e', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0203@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Nguyễn Hương Giang', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '72056029-3a7a-4729-b821-c5e34737aa3e', '72056029-3a7a-4729-b821-c5e34737aa3e', jsonb_build_object('sub', '72056029-3a7a-4729-b821-c5e34737aa3e', 'email', 'cudan.a0203@gmail.com'),
            'email', '72056029-3a7a-4729-b821-c5e34737aa3e', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('72056029-3a7a-4729-b821-c5e34737aa3e', 'Nguyễn Hương Giang', '0911002003', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0301@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'ebaba7db-496a-49e9-a6b8-c99b27f69fbc', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0301@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Lê Quang Huy', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'ebaba7db-496a-49e9-a6b8-c99b27f69fbc', 'ebaba7db-496a-49e9-a6b8-c99b27f69fbc', jsonb_build_object('sub', 'ebaba7db-496a-49e9-a6b8-c99b27f69fbc', 'email', 'cudan.a0301@gmail.com'),
            'email', 'ebaba7db-496a-49e9-a6b8-c99b27f69fbc', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('ebaba7db-496a-49e9-a6b8-c99b27f69fbc', 'Lê Quang Huy', '0911003001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0302@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'aad9f201-ecf8-4d47-bf15-856876f87e33', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0302@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Đỗ Mạnh Cường', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'aad9f201-ecf8-4d47-bf15-856876f87e33', 'aad9f201-ecf8-4d47-bf15-856876f87e33', jsonb_build_object('sub', 'aad9f201-ecf8-4d47-bf15-856876f87e33', 'email', 'cudan.a0302@gmail.com'),
            'email', 'aad9f201-ecf8-4d47-bf15-856876f87e33', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('aad9f201-ecf8-4d47-bf15-856876f87e33', 'Đỗ Mạnh Cường', '0911003002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0401@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '89ae22b5-5a70-4a9e-ada0-807dade4c0d9', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0401@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Phan Thùy Dương', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '89ae22b5-5a70-4a9e-ada0-807dade4c0d9', '89ae22b5-5a70-4a9e-ada0-807dade4c0d9', jsonb_build_object('sub', '89ae22b5-5a70-4a9e-ada0-807dade4c0d9', 'email', 'cudan.a0401@gmail.com'),
            'email', '89ae22b5-5a70-4a9e-ada0-807dade4c0d9', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('89ae22b5-5a70-4a9e-ada0-807dade4c0d9', 'Phan Thùy Dương', '0911004001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.a0501@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'aded4b2c-879b-4ddf-b61a-243bcbc4abdc', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.a0501@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Trần Bảo Nam', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'aded4b2c-879b-4ddf-b61a-243bcbc4abdc', 'aded4b2c-879b-4ddf-b61a-243bcbc4abdc', jsonb_build_object('sub', 'aded4b2c-879b-4ddf-b61a-243bcbc4abdc', 'email', 'cudan.a0501@gmail.com'),
            'email', 'aded4b2c-879b-4ddf-b61a-243bcbc4abdc', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('aded4b2c-879b-4ddf-b61a-243bcbc4abdc', 'Trần Bảo Nam', '0911005001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0101@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '176c34fa-4f14-4338-a680-692d435c66f3', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0101@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Hoàng Ngọc Tuấn', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '176c34fa-4f14-4338-a680-692d435c66f3', '176c34fa-4f14-4338-a680-692d435c66f3', jsonb_build_object('sub', '176c34fa-4f14-4338-a680-692d435c66f3', 'email', 'cudan.b0101@gmail.com'),
            'email', '176c34fa-4f14-4338-a680-692d435c66f3', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('176c34fa-4f14-4338-a680-692d435c66f3', 'Hoàng Ngọc Tuấn', '0912001001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0102@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '50cf2dc9-951a-4d23-b50c-13a4595527dd', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0102@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Mai Kim Oanh', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '50cf2dc9-951a-4d23-b50c-13a4595527dd', '50cf2dc9-951a-4d23-b50c-13a4595527dd', jsonb_build_object('sub', '50cf2dc9-951a-4d23-b50c-13a4595527dd', 'email', 'cudan.b0102@gmail.com'),
            'email', '50cf2dc9-951a-4d23-b50c-13a4595527dd', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('50cf2dc9-951a-4d23-b50c-13a4595527dd', 'Mai Kim Oanh', '0912001002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0201@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'c60cd64b-736a-4b90-81b5-fdaa510a341a', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0201@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Dương Văn Khánh', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'c60cd64b-736a-4b90-81b5-fdaa510a341a', 'c60cd64b-736a-4b90-81b5-fdaa510a341a', jsonb_build_object('sub', 'c60cd64b-736a-4b90-81b5-fdaa510a341a', 'email', 'cudan.b0201@gmail.com'),
            'email', 'c60cd64b-736a-4b90-81b5-fdaa510a341a', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('c60cd64b-736a-4b90-81b5-fdaa510a341a', 'Dương Văn Khánh', '0912002001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0202@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'b05a77d7-defa-41a0-8abf-e1d5925e5fa7', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0202@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Hoàng Thùy Linh', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'b05a77d7-defa-41a0-8abf-e1d5925e5fa7', 'b05a77d7-defa-41a0-8abf-e1d5925e5fa7', jsonb_build_object('sub', 'b05a77d7-defa-41a0-8abf-e1d5925e5fa7', 'email', 'cudan.b0202@gmail.com'),
            'email', 'b05a77d7-defa-41a0-8abf-e1d5925e5fa7', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('b05a77d7-defa-41a0-8abf-e1d5925e5fa7', 'Hoàng Thùy Linh', '0912002002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0301@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'cf0c017c-eafe-4904-bba1-232ff966c69c', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0301@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Cao Thị Tuyết', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'cf0c017c-eafe-4904-bba1-232ff966c69c', 'cf0c017c-eafe-4904-bba1-232ff966c69c', jsonb_build_object('sub', 'cf0c017c-eafe-4904-bba1-232ff966c69c', 'email', 'cudan.b0301@gmail.com'),
            'email', 'cf0c017c-eafe-4904-bba1-232ff966c69c', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('cf0c017c-eafe-4904-bba1-232ff966c69c', 'Cao Thị Tuyết', '0912003001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0302@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '6eeafd52-be30-403b-bdc6-bf2ad8fa009c', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0302@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Lương Gia Bảo', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '6eeafd52-be30-403b-bdc6-bf2ad8fa009c', '6eeafd52-be30-403b-bdc6-bf2ad8fa009c', jsonb_build_object('sub', '6eeafd52-be30-403b-bdc6-bf2ad8fa009c', 'email', 'cudan.b0302@gmail.com'),
            'email', '6eeafd52-be30-403b-bdc6-bf2ad8fa009c', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('6eeafd52-be30-403b-bdc6-bf2ad8fa009c', 'Lương Gia Bảo', '0912003002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0401@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '1f00eb49-bb60-42f6-b4b3-791399792c20', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0401@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Ngô Thành Đạt', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '1f00eb49-bb60-42f6-b4b3-791399792c20', '1f00eb49-bb60-42f6-b4b3-791399792c20', jsonb_build_object('sub', '1f00eb49-bb60-42f6-b4b3-791399792c20', 'email', 'cudan.b0401@gmail.com'),
            'email', '1f00eb49-bb60-42f6-b4b3-791399792c20', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('1f00eb49-bb60-42f6-b4b3-791399792c20', 'Ngô Thành Đạt', '0912004001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.b0501@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'd6e120fc-4e33-4592-914b-f025f8115af9', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.b0501@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Tạ Thu Hương', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'd6e120fc-4e33-4592-914b-f025f8115af9', 'd6e120fc-4e33-4592-914b-f025f8115af9', jsonb_build_object('sub', 'd6e120fc-4e33-4592-914b-f025f8115af9', 'email', 'cudan.b0501@gmail.com'),
            'email', 'd6e120fc-4e33-4592-914b-f025f8115af9', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('d6e120fc-4e33-4592-914b-f025f8115af9', 'Tạ Thu Hương', '0912005001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0101@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'dec4076b-f830-42ca-a5ac-b7e60514081b', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0101@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Đinh Trọng Nghĩa', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'dec4076b-f830-42ca-a5ac-b7e60514081b', 'dec4076b-f830-42ca-a5ac-b7e60514081b', jsonb_build_object('sub', 'dec4076b-f830-42ca-a5ac-b7e60514081b', 'email', 'cudan.c0101@gmail.com'),
            'email', 'dec4076b-f830-42ca-a5ac-b7e60514081b', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('dec4076b-f830-42ca-a5ac-b7e60514081b', 'Đinh Trọng Nghĩa', '0913001001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0102@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '0b1d4163-cd54-4a24-86dc-0aee5d33f637', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0102@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Hà Kiều Anh', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '0b1d4163-cd54-4a24-86dc-0aee5d33f637', '0b1d4163-cd54-4a24-86dc-0aee5d33f637', jsonb_build_object('sub', '0b1d4163-cd54-4a24-86dc-0aee5d33f637', 'email', 'cudan.c0102@gmail.com'),
            'email', '0b1d4163-cd54-4a24-86dc-0aee5d33f637', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('0b1d4163-cd54-4a24-86dc-0aee5d33f637', 'Hà Kiều Anh', '0913001002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0201@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0201@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Đoàn Văn Hậu', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', '162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', jsonb_build_object('sub', '162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', 'email', 'cudan.c0201@gmail.com'),
            'email', '162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', 'Đoàn Văn Hậu', '0913002001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0202@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '6a286f83-16b3-442e-a15c-aa7464654f8d', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0202@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Võ Minh Quân', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '6a286f83-16b3-442e-a15c-aa7464654f8d', '6a286f83-16b3-442e-a15c-aa7464654f8d', jsonb_build_object('sub', '6a286f83-16b3-442e-a15c-aa7464654f8d', 'email', 'cudan.c0202@gmail.com'),
            'email', '6a286f83-16b3-442e-a15c-aa7464654f8d', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('6a286f83-16b3-442e-a15c-aa7464654f8d', 'Võ Minh Quân', '0913002002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0301@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'c2648b1e-0d9e-46cb-a9ad-a9606b584a56', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0301@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Đỗ Quang Hải', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'c2648b1e-0d9e-46cb-a9ad-a9606b584a56', 'c2648b1e-0d9e-46cb-a9ad-a9606b584a56', jsonb_build_object('sub', 'c2648b1e-0d9e-46cb-a9ad-a9606b584a56', 'email', 'cudan.c0301@gmail.com'),
            'email', 'c2648b1e-0d9e-46cb-a9ad-a9606b584a56', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('c2648b1e-0d9e-46cb-a9ad-a9606b584a56', 'Đỗ Quang Hải', '0913003001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0401@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'baddd372-af60-46eb-bcbf-1b96ce01059e', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0401@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Quách Ánh Tuyết', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'baddd372-af60-46eb-bcbf-1b96ce01059e', 'baddd372-af60-46eb-bcbf-1b96ce01059e', jsonb_build_object('sub', 'baddd372-af60-46eb-bcbf-1b96ce01059e', 'email', 'cudan.c0401@gmail.com'),
            'email', 'baddd372-af60-46eb-bcbf-1b96ce01059e', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('baddd372-af60-46eb-bcbf-1b96ce01059e', 'Quách Ánh Tuyết', '0913004001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'cudan.c0501@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '6ed70475-f500-4f2e-8eff-ef315b976c48', '00000000-0000-0000-0000-000000000000'::uuid, 'cudan.c0501@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Nghiêm Xuân Tú', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '6ed70475-f500-4f2e-8eff-ef315b976c48', '6ed70475-f500-4f2e-8eff-ef315b976c48', jsonb_build_object('sub', '6ed70475-f500-4f2e-8eff-ef315b976c48', 'email', 'cudan.c0501@gmail.com'),
            'email', '6ed70475-f500-4f2e-8eff-ef315b976c48', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('6ed70475-f500-4f2e-8eff-ef315b976c48', 'Nghiêm Xuân Tú', '0913005001', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'nguoithan.a0101@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'be7b5345-950c-4e43-b771-972e591c1848', '00000000-0000-0000-0000-000000000000'::uuid, 'nguoithan.a0101@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Nguyễn Thị Lan', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'be7b5345-950c-4e43-b771-972e591c1848', 'be7b5345-950c-4e43-b771-972e591c1848', jsonb_build_object('sub', 'be7b5345-950c-4e43-b771-972e591c1848', 'email', 'nguoithan.a0101@gmail.com'),
            'email', 'be7b5345-950c-4e43-b771-972e591c1848', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('be7b5345-950c-4e43-b771-972e591c1848', 'Nguyễn Thị Lan', '0911001002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'nguoithan.c0301@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'e2354b53-aecf-4040-b908-9f788aea0996', '00000000-0000-0000-0000-000000000000'::uuid, 'nguoithan.c0301@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Đỗ Hải Yến', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'e2354b53-aecf-4040-b908-9f788aea0996', 'e2354b53-aecf-4040-b908-9f788aea0996', jsonb_build_object('sub', 'e2354b53-aecf-4040-b908-9f788aea0996', 'email', 'nguoithan.c0301@gmail.com'),
            'email', 'e2354b53-aecf-4040-b908-9f788aea0996', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('e2354b53-aecf-4040-b908-9f788aea0996', 'Đỗ Hải Yến', '0913003002', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'test1@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            '822f402d-e262-4f56-9581-9ee36ef5fff7', '00000000-0000-0000-0000-000000000000'::uuid, 'test1@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Phạm Văn Minh', 'role', 'resident'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            '822f402d-e262-4f56-9581-9ee36ef5fff7', '822f402d-e262-4f56-9581-9ee36ef5fff7', jsonb_build_object('sub', '822f402d-e262-4f56-9581-9ee36ef5fff7', 'email', 'test1@gmail.com'),
            'email', '822f402d-e262-4f56-9581-9ee36ef5fff7', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('822f402d-e262-4f56-9581-9ee36ef5fff7', 'Phạm Văn Minh', '0934567890', 'resident'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'cb0fbd95-971a-4fb4-8f0d-8c7236184261', '00000000-0000-0000-0000-000000000000'::uuid, 'admin@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Nguyễn Văn Quản Trị', 'role', 'admin'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'cb0fbd95-971a-4fb4-8f0d-8c7236184261', 'cb0fbd95-971a-4fb4-8f0d-8c7236184261', jsonb_build_object('sub', 'cb0fbd95-971a-4fb4-8f0d-8c7236184261', 'email', 'admin@gmail.com'),
            'email', 'cb0fbd95-971a-4fb4-8f0d-8c7236184261', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('cb0fbd95-971a-4fb4-8f0d-8c7236184261', 'Nguyễn Văn Quản Trị', '0901234567', 'admin'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'pkahome.admin@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'cefe60f0-571b-4b5c-a924-8081a5fcf05a', '00000000-0000-0000-0000-000000000000'::uuid, 'pkahome.admin@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Nguyễn Văn An', 'role', 'admin'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'cefe60f0-571b-4b5c-a924-8081a5fcf05a', 'cefe60f0-571b-4b5c-a924-8081a5fcf05a', jsonb_build_object('sub', 'cefe60f0-571b-4b5c-a924-8081a5fcf05a', 'email', 'pkahome.admin@gmail.com'),
            'email', 'cefe60f0-571b-4b5c-a924-8081a5fcf05a', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('cefe60f0-571b-4b5c-a924-8081a5fcf05a', 'Nguyễn Văn An', '0901234567', 'admin'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'pkahome.ketoan@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'd7e4bf49-b118-41ba-a71e-5af79d79c80c', '00000000-0000-0000-0000-000000000000'::uuid, 'pkahome.ketoan@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Trần Thị Mai', 'role', 'accountant'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'd7e4bf49-b118-41ba-a71e-5af79d79c80c', 'd7e4bf49-b118-41ba-a71e-5af79d79c80c', jsonb_build_object('sub', 'd7e4bf49-b118-41ba-a71e-5af79d79c80c', 'email', 'pkahome.ketoan@gmail.com'),
            'email', 'd7e4bf49-b118-41ba-a71e-5af79d79c80c', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('d7e4bf49-b118-41ba-a71e-5af79d79c80c', 'Trần Thị Mai', '0902345678', 'accountant'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'pkahome.kythuat@gmail.com') THEN
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
        ) VALUES (
            'fa5ac694-df11-4c09-b059-584e5d92bae3', '00000000-0000-0000-0000-000000000000'::uuid, 'pkahome.kythuat@gmail.com',
            crypt('PkaHome@2026', gen_salt('bf')), NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('full_name', 'Lê Hoàng Long', 'role', 'technician'),
            NOW(), NOW(), 'authenticated', 'authenticated'
        );
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            'fa5ac694-df11-4c09-b059-584e5d92bae3', 'fa5ac694-df11-4c09-b059-584e5d92bae3', jsonb_build_object('sub', 'fa5ac694-df11-4c09-b059-584e5d92bae3', 'email', 'pkahome.kythuat@gmail.com'),
            'email', 'fa5ac694-df11-4c09-b059-584e5d92bae3', NOW(), NOW(), NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.users (id, full_name, phone, role, is_locked)
    VALUES ('fa5ac694-df11-4c09-b059-584e5d92bae3', 'Lê Hoàng Long', '0903456789', 'technician'::public.user_role, false)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role;
END $$;

-- 3. LIÊN KẾT CƯ DÂN VÀO 25 CĂN HỘ ĐANG CƯ TRÚ
DO $$
BEGIN

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'be7b5345-950c-4e43-b771-972e591c1848', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'a84c3099-f173-433c-8a8e-5990eeb8aad9', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'edc08186-8cd1-4b53-9e6c-55d0d9922276', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '07ad14a4-1af5-4a08-ab25-a4db4354a106', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0102';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '4f89c188-841e-4936-854b-a70393c265be', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0102';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'f5547802-196d-475b-877d-c0ea2c3d3910', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0103'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0103';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '4a231008-4b9b-4946-86a8-6d041ce67812', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0103'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0103';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '65410e2a-cd15-4c01-a19b-7ce65c6fe4e6', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0201';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '822f402d-e262-4f56-9581-9ee36ef5fff7', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0202';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '83127e15-3c5c-48ea-99ef-c0666230b225', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0202';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '72056029-3a7a-4729-b821-c5e34737aa3e', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0203'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0203';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'ebaba7db-496a-49e9-a6b8-c99b27f69fbc', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0301';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'aad9f201-ecf8-4d47-bf15-856876f87e33', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0302'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0302';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '89ae22b5-5a70-4a9e-ada0-807dade4c0d9', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0401';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'aded4b2c-879b-4ddf-b61a-243bcbc4abdc', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'A0501';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '78fbb083-ee75-4144-9bc8-79f79a49584a', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '176c34fa-4f14-4338-a680-692d435c66f3', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '50cf2dc9-951a-4d23-b50c-13a4595527dd', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0102';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'c60cd64b-736a-4b90-81b5-fdaa510a341a', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0201';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'b05a77d7-defa-41a0-8abf-e1d5925e5fa7', 'tenant'::public.relation_type
    FROM public.apartments WHERE code = 'B0202'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0202';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'cf0c017c-eafe-4904-bba1-232ff966c69c', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0301'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0301';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '6eeafd52-be30-403b-bdc6-bf2ad8fa009c', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0302';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '1f00eb49-bb60-42f6-b4b3-791399792c20', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0401';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'd6e120fc-4e33-4592-914b-f025f8115af9', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'B0501'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'B0501';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'dec4076b-f830-42ca-a5ac-b7e60514081b', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '17a9f297-6fb8-45b0-a9e7-a598fd770684', 'tenant'::public.relation_type
    FROM public.apartments WHERE code = 'C0101'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0101';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '0b1d4163-cd54-4a24-86dc-0aee5d33f637', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0102'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0102';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '162e6e1c-2a15-4dd5-adb4-ab67cc4a91c1', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0201';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '6a286f83-16b3-442e-a15c-aa7464654f8d', 'tenant'::public.relation_type
    FROM public.apartments WHERE code = 'C0202'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0202';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'c2648b1e-0d9e-46cb-a9ad-a9606b584a56', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0301';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'e2354b53-aecf-4040-b908-9f788aea0996', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0301';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, 'baddd372-af60-46eb-bcbf-1b96ce01059e', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0401';

    INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role)
    SELECT id, '6ed70475-f500-4f2e-8eff-ef315b976c48', 'owner'::public.relation_type
    FROM public.apartments WHERE code = 'C0501'
    ON CONFLICT DO NOTHING;

    UPDATE public.apartments SET is_empty = false WHERE code = 'C0501';
END $$;

-- 4. SEED PHƯƠNG TIỆN (THẺ XE ĐÃ DUYỆT, CHỜ DUYỆT, TỪ CHỐI)
ALTER TABLE public.vehicles DISABLE TRIGGER trg_check_vehicle_limits;
DO $$
BEGIN

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29B1-678.90', '29B1-678.90', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29B1-678.90', '29B1-678.90', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29A1-123.45', '29A1-123.45', 'Honda SH 150i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29B1-678.90', '29B1-678.90', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29A1-123.45', '29A1-123.45', 'Honda SH 150i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29B1-678.90', '29B1-678.90', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29A1-123.45', '29A1-123.45', 'Honda SH 150i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29A1-123.45', '29A1-123.45', 'Honda SH 150i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29C1-111.22', '29C1-111.22', 'Yamaha Grande', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-888.88', '30H-888.88', 'Mazda CX-5', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29C1-111.22', '29C1-111.22', 'Yamaha Grande', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-888.88', '30H-888.88', 'Mazda CX-5', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29C1-111.22', '29C1-111.22', 'Yamaha Grande', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-888.88', '30H-888.88', 'Mazda CX-5', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-888.88', '30H-888.88', 'Mazda CX-5', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29C1-111.22', '29C1-111.22', 'Yamaha Grande', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29D1-333.44', '29D1-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0103'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29D1-333.44', '29D1-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0103'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29D1-333.44', '29D1-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0103'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29D1-333.44', '29D1-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0103'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-666.66', '30G-666.66', 'Toyota Camry', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29E1-555.66', '29E1-555.66', 'Vespa Sprint', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-666.66', '30G-666.66', 'Toyota Camry', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-666.66', '30G-666.66', 'Toyota Camry', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29E1-555.66', '29E1-555.66', 'Vespa Sprint', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29E1-555.66', '29E1-555.66', 'Vespa Sprint', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-666.66', '30G-666.66', 'Toyota Camry', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29E1-555.66', '29E1-555.66', 'Vespa Sprint', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-777.88', '29F1-777.88', 'Honda Lead', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-999.00', '29F1-999.00', 'Yamaha NVX', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-999.00', '29F1-999.00', 'Yamaha NVX', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-999.00', '29F1-999.00', 'Yamaha NVX', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-777.88', '29F1-777.88', 'Honda Lead', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-777.88', '29F1-777.88', 'Honda Lead', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-999.00', '29F1-999.00', 'Yamaha NVX', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29F1-777.88', '29F1-777.88', 'Honda Lead', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-123.99', '30E-123.99', 'Hyundai Tucson', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0203'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-123.99', '30E-123.99', 'Hyundai Tucson', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0203'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-123.99', '30E-123.99', 'Hyundai Tucson', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0203'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-123.99', '30E-123.99', 'Hyundai Tucson', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0203'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29H1-222.33', '29H1-222.33', 'Honda Wave Alpha', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29H1-222.33', '29H1-222.33', 'Honda Wave Alpha', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29H1-222.33', '29H1-222.33', 'Honda Wave Alpha', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29H1-222.33', '29H1-222.33', 'Honda Wave Alpha', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-991.23', '30H-991.23', 'Kia Carnival', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-991.23', '30H-991.23', 'Kia Carnival', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-991.23', '30H-991.23', 'Kia Carnival', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-991.23', '30H-991.23', 'Kia Carnival', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29K1-444.55', '29K1-444.55', 'Honda Winner X', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29K1-444.55', '29K1-444.55', 'Honda Winner X', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29K1-444.55', '29K1-444.55', 'Honda Winner X', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29K1-444.55', '29K1-444.55', 'Honda Winner X', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-888.99', '29M1-888.99', 'Honda SH Mode', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30A-999.11', '30A-999.11', 'Mercedes-Benz C200', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-888.99', '29M1-888.99', 'Honda SH Mode', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30A-999.11', '30A-999.11', 'Mercedes-Benz C200', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30A-999.11', '30A-999.11', 'Mercedes-Benz C200', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30A-999.11', '30A-999.11', 'Mercedes-Benz C200', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-888.99', '29M1-888.99', 'Honda SH Mode', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-888.99', '29M1-888.99', 'Honda SH Mode', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30F-555.22', '30F-555.22', 'VinFast VF8', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30F-555.22', '30F-555.22', 'VinFast VF8', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30F-555.22', '30F-555.22', 'VinFast VF8', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30F-555.22', '30F-555.22', 'VinFast VF8', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-999.99', '29M1-999.99', 'Yamaha R15', 'rejected', 'Biển số xe không hợp lệ trên cơ sở dữ liệu đăng kiểm.', NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-999.99', '29M1-999.99', 'Yamaha R15', 'rejected', 'Biển số xe không hợp lệ trên cơ sở dữ liệu đăng kiểm.', NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-999.99', '29M1-999.99', 'Yamaha R15', 'rejected', 'Biển số xe không hợp lệ trên cơ sở dữ liệu đăng kiểm.', NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29M1-999.99', '29M1-999.99', 'Yamaha R15', 'rejected', 'Biển số xe không hợp lệ trên cơ sở dữ liệu đăng kiểm.', NOW(), NOW()
    FROM public.apartments WHERE code = 'A0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-112.23', '59X1-112.23', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-112.23', '59X1-112.23', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-112.23', '59X1-112.23', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-112.23', '59X1-112.23', 'Honda Vision', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-999.88', '59X1-999.88', 'Yamaha FreeGo', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-999.88', '59X1-999.88', 'Yamaha FreeGo', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-999.88', '59X1-999.88', 'Yamaha FreeGo', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X1-999.88', '59X1-999.88', 'Yamaha FreeGo', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X2-334.45', '59X2-334.45', 'Yamaha Janus', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '51K-889.90', '51K-889.90', 'Kia Seltos', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X2-334.45', '59X2-334.45', 'Yamaha Janus', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X2-334.45', '59X2-334.45', 'Yamaha Janus', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '59X2-334.45', '59X2-334.45', 'Yamaha Janus', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '51K-889.90', '51K-889.90', 'Kia Seltos', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '51K-889.90', '51K-889.90', 'Kia Seltos', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '51K-889.90', '51K-889.90', 'Kia Seltos', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-123.88', '29P1-123.88', 'Honda AirBlade 160', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-123.88', '29P1-123.88', 'Honda AirBlade 160', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-123.88', '29P1-123.88', 'Honda AirBlade 160', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-123.88', '29P1-123.88', 'Honda AirBlade 160', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-777.66', '29P1-777.66', 'Honda Beat', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-777.66', '29P1-777.66', 'Honda Beat', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-777.66', '29P1-777.66', 'Honda Beat', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29P1-777.66', '29P1-777.66', 'Honda Beat', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-234.56', '30H-234.56', 'Honda CR-V', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-234.56', '30H-234.56', 'Honda CR-V', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-234.56', '30H-234.56', 'Honda CR-V', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-234.56', '30H-234.56', 'Honda CR-V', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-345.67', '29T1-345.67', 'Yamaha Exciter', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-345.67', '29T1-345.67', 'Yamaha Exciter', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-345.67', '29T1-345.67', 'Yamaha Exciter', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-345.67', '29T1-345.67', 'Yamaha Exciter', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29U1-456.78', '29U1-456.78', 'Honda Lead 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-789.01', '30E-789.01', 'Ford Everest', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29U1-456.78', '29U1-456.78', 'Honda Lead 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-789.01', '30E-789.01', 'Ford Everest', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29U1-456.78', '29U1-456.78', 'Honda Lead 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-789.01', '30E-789.01', 'Ford Everest', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29U1-456.78', '29U1-456.78', 'Honda Lead 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30E-789.01', '30E-789.01', 'Ford Everest', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0302'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-445.67', '30H-445.67', 'Hyundai Santa Fe', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-445.67', '30H-445.67', 'Hyundai Santa Fe', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-445.67', '30H-445.67', 'Hyundai Santa Fe', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30H-445.67', '30H-445.67', 'Hyundai Santa Fe', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-888.77', '29T1-888.77', 'Honda CBR150R', 'rejected', 'Vượt quá hạn mức xe máy tối đa của căn hộ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-888.77', '29T1-888.77', 'Honda CBR150R', 'rejected', 'Vượt quá hạn mức xe máy tối đa của căn hộ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-888.77', '29T1-888.77', 'Honda CBR150R', 'rejected', 'Vượt quá hạn mức xe máy tối đa của căn hộ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29T1-888.77', '29T1-888.77', 'Honda CBR150R', 'rejected', 'Vượt quá hạn mức xe máy tối đa của căn hộ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'B0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-998.87', '30G-998.87', 'BMW 320i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-998.87', '30G-998.87', 'BMW 320i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-998.87', '30G-998.87', 'BMW 320i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30G-998.87', '30G-998.87', 'BMW 320i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'B0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29V1-567.89', '29V1-567.89', 'Honda Future 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29V1-567.89', '29V1-567.89', 'Honda Future 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29V1-567.89', '29V1-567.89', 'Honda Future 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29V1-567.89', '29V1-567.89', 'Honda Future 125', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0101'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29X1-678.90', '29X1-678.90', 'Honda Vision Smartkey', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29X1-678.90', '29X1-678.90', 'Honda Vision Smartkey', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29X1-678.90', '29X1-678.90', 'Honda Vision Smartkey', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29X1-678.90', '29X1-678.90', 'Honda Vision Smartkey', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0102'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-112.34', '30K-112.34', 'Toyota Corolla Cross', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Y1-789.01', '29Y1-789.01', 'Vespa GTS 150', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-112.34', '30K-112.34', 'Toyota Corolla Cross', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Y1-789.01', '29Y1-789.01', 'Vespa GTS 150', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Y1-789.01', '29Y1-789.01', 'Vespa GTS 150', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-112.34', '30K-112.34', 'Toyota Corolla Cross', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Y1-789.01', '29Y1-789.01', 'Vespa GTS 150', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-112.34', '30K-112.34', 'Toyota Corolla Cross', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0201'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Z1-890.12', '29Z1-890.12', 'Yamaha Sirius', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Z1-890.12', '29Z1-890.12', 'Yamaha Sirius', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Z1-890.12', '29Z1-890.12', 'Yamaha Sirius', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29Z1-890.12', '29Z1-890.12', 'Yamaha Sirius', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0202'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-333.44', '29AA-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-111.22', '29AA-111.22', 'Honda SH 125i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-111.22', '29AA-111.22', 'Honda SH 125i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-111.22', '29AA-111.22', 'Honda SH 125i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-333.44', '29AA-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-333.44', '29AA-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-333.44', '29AA-333.44', 'Honda AirBlade', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AA-111.22', '29AA-111.22', 'Honda SH 125i', 'approved', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0301'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AB-555.66', '29AB-555.66', 'Honda Blade', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AB-555.66', '29AB-555.66', 'Honda Blade', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AB-555.66', '29AB-555.66', 'Honda Blade', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AB-555.66', '29AB-555.66', 'Honda Blade', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-999.88', '30K-999.88', 'Toyota Vios', 'rejected', 'Thiếu ảnh chụp giấy đăng ký xe chính chủ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-999.88', '30K-999.88', 'Toyota Vios', 'rejected', 'Thiếu ảnh chụp giấy đăng ký xe chính chủ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-999.88', '30K-999.88', 'Toyota Vios', 'rejected', 'Thiếu ảnh chụp giấy đăng ký xe chính chủ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'car', '30K-999.88', '30K-999.88', 'Toyota Vios', 'rejected', 'Thiếu ảnh chụp giấy đăng ký xe chính chủ.', NOW(), NOW()
    FROM public.apartments WHERE code = 'C0401'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AC-777.88', '29AC-777.88', 'Vespa Primavera', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AC-777.88', '29AC-777.88', 'Vespa Primavera', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AC-777.88', '29AC-777.88', 'Vespa Primavera', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0501'
    ON CONFLICT DO NOTHING;

    INSERT INTO public.vehicles (
        apartment_id, vehicle_type, license_plate, plate_number, brand_model,
        status, rejection_reason, created_at, updated_at
    )
    SELECT id, 'motorbike', '29AC-777.88', '29AC-777.88', 'Vespa Primavera', 'pending', NULL, NOW(), NOW()
    FROM public.apartments WHERE code = 'C0501'
    ON CONFLICT DO NOTHING;
END $$;
ALTER TABLE public.vehicles ENABLE TRIGGER trg_check_vehicle_limits;

-- 5. SEED TRANG THIẾT BỊ VẬN HÀNH & KẾ HOẠCH BẢO TRÌ

INSERT INTO public.building_equipments (
    code, name, category, building, location, maintenance_interval_days,
    last_maintenance_date, next_maintenance_date, status, specifications
) VALUES (
    'MB-01', 'Hệ thống máy bơm tăng áp nước sinh hoạt toàn khu', 'water_pump', 'Toàn khu', 'Phòng kỹ thuật nước Tầng hầm B2', 60,
    NOW() - interval '25 days', NOW() + interval '5 days', 'operational', 'Công suất 15kW, Lưu lượng 60m3/h, Hãng Grundfos'
) ON CONFLICT (code) DO NOTHING;

INSERT INTO public.building_equipments (
    code, name, category, building, location, maintenance_interval_days,
    last_maintenance_date, next_maintenance_date, status, specifications
) VALUES (
    'MPD-01', 'Máy phát điện dự phòng Cummins 750kVA', 'generator', 'Toàn khu', 'Phòng máy phát Tầng hầm B2', 90,
    NOW() - interval '25 days', NOW() + interval '5 days', 'operational', 'Công suất 750kVA, Nhiên liệu Diesel, Khởi động tự động ATS trong 10s'
) ON CONFLICT (code) DO NOTHING;

INSERT INTO public.building_equipments (
    code, name, category, building, location, maintenance_interval_days,
    last_maintenance_date, next_maintenance_date, status, specifications
) VALUES (
    'PCCC-A01', 'Hệ thống chuông còi & đầu phun Spinkler Tòa A', 'fire_safety', 'Tòa A', 'Toàn bộ hành lang và tầng hầm Tòa A', 90,
    NOW() - interval '25 days', NOW() + interval '5 days', 'operational', 'Áp lực 12 bar, Trung tâm điều khiển Hochiki Nhật Bản'
) ON CONFLICT (code) DO NOTHING;

INSERT INTO public.building_equipments (
    code, name, category, building, location, maintenance_interval_days,
    last_maintenance_date, next_maintenance_date, status, specifications
) VALUES (
    'TM-A01', 'Thang máy chở khách A1', 'elevator', 'Tòa A', 'Trục lõi Tòa A (Tầng B2 - Tầng 25)', 30,
    NOW() - interval '25 days', NOW() + interval '5 days', 'operational', 'Tải trọng 1000kg (13 người), Tốc độ 2.5m/s, Hãng Schindler'
) ON CONFLICT (code) DO NOTHING;

INSERT INTO public.building_equipments (
    code, name, category, building, location, maintenance_interval_days,
    last_maintenance_date, next_maintenance_date, status, specifications
) VALUES (
    'TM-B01', 'Thang máy tải khách B1', 'elevator', 'Tòa B', 'Trục lõi Tòa B (Tầng B2 - Tầng 25)', 30,
    NOW() - interval '25 days', NOW() + interval '5 days', 'operational', 'Tải trọng 1000kg, Hãng Mitsubishi'
) ON CONFLICT (code) DO NOTHING;

-- 6. TIỆN ÍCH TÒA NHÀ

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Hồ bơi ngoài trời (Tầng 5)', 'Miễn phí cho cư dân có thẻ. Vui lòng mặc trang phục bơi quy định và tắm tráng trước khi xuống hồ.', '06:00 - 21:00', 1
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Hồ bơi ngoài trời (Tầng 5)');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Hồ bơi bốn mùa (Tầng 5)', 'Hồ bơi nước ấm tiêu chuẩn với làn bơi riêng cho người lớn và trẻ em', '06:00 - 21:00', 1
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Hồ bơi bốn mùa (Tầng 5)');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Phòng Gym & Yoga cao cấp (Tầng 4)', 'Đầy đủ thiết bị tập gym, tạ tay, máy chạy bộ Technogym hiện đại', '05:30 - 22:00', 2
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Phòng Gym & Yoga cao cấp (Tầng 4)');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Phòng Gym & Yoga (Tầng 4)', 'Trang bị máy tập hiện đại. Cư dân tự mang khăn cá nhân và xếp gọn tạ sau khi sử dụng.', '05:30 - 22:00', 2
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Phòng Gym & Yoga (Tầng 4)');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Phòng sinh hoạt cộng đồng (Tầng 1)', 'Khu vực họp cư dân, đọc sách và tổ chức sự kiện gia đình (cần đăng ký trước với BQL).', '08:00 - 21:30', 3
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Phòng sinh hoạt cộng đồng (Tầng 1)');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Phòng sinh hoạt cộng đồng', 'Không gian hội họp, đọc sách và tổ chức sự kiện nhỏ cho cư dân', '08:00 - 21:30', 3
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Phòng sinh hoạt cộng đồng');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Sân Tennis tiêu chuẩn (Tầng 6)', 'Sân cứng tiêu chuẩn quốc tế, đèn chiếu sáng ban đêm', '06:00 - 22:00', 4
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Sân Tennis tiêu chuẩn (Tầng 6)');

INSERT INTO public.building_amenities (name, description, open_hours, display_order)
SELECT 'Khu tiệc nướng BBQ ngoài trời (Tầng thượng)', 'Bếp nướng điện & than cao cấp, bàn ăn gia đình ngắm view thành phố', '16:00 - 22:00', 5
WHERE NOT EXISTS (SELECT 1 FROM public.building_amenities WHERE name = 'Khu tiệc nướng BBQ ngoài trời (Tầng thượng)');

-- 7. THÔNG BÁO TÒA NHÀ

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Thông báo lịch nghỉ Lễ và ca trực 24/7 của Đội ngũ Kỹ thuật & Bảo vệ', 'Ban Quản Lý duy trì đội ngũ trực hotline khẩn cấp 24/7 trong suốt các ngày nghỉ. Mọi sự cố kỹ thuật vui lòng gửi phản ánh trực tiếp trên app hoặc gọi Hotline.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Thông báo lịch nghỉ Lễ và ca trực 24/7 của Đội ngũ Kỹ thuật & Bảo vệ');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Bảo trì hệ thống camera an ninh hầm xe Block C', 'Kỹ thuật viên sẽ kiểm tra và nâng cấp mắt đọc camera lối vào hầm xe Block C từ 09:00 đến 11:30 ngày 15/10/2026.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Bảo trì hệ thống camera an ninh hầm xe Block C');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Nhắc nhở phân loại rác thải sinh hoạt tại nguồn', 'Kính mong cư dân phân loại rác hữu cơ và rác tái chế trước khi bỏ vào phòng rác tầng nhằm chung tay giữ gìn môi trường xanh - sạch - đẹp của tòa nhà.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Nhắc nhở phân loại rác thải sinh hoạt tại nguồn');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Mở đăng ký giải bơi lội thanh thiếu niên mùa thu PKA-Home 2026', 'Giải đấu giao lưu bơi lội dành cho con em cư dân từ 8 đến 16 tuổi tại Hồ bơi Tầng 5. Cư dân đăng ký miễn phí tại văn phòng BQL hoặc qua ứng dụng.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Mở đăng ký giải bơi lội thanh thiếu niên mùa thu PKA-Home 2026');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Quy định nhắc nhở về tiếng ồn và giờ giấc sinh hoạt sau 22h00', 'Để bảo đảm không gian yên tĩnh và giấc ngủ cho các hộ lân cận, BQL kính đề nghị cư dân không bật nhạc âm lượng lớn hoặc thi công khoan đục sau 22h00 đêm.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Quy định nhắc nhở về tiếng ồn và giờ giấc sinh hoạt sau 22h00');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Thông báo phun thuốc diệt muỗi và côn trùng khu vực công cộng', 'Ban Quản Lý sẽ phun thuốc diệt côn trùng toàn bộ khuôn viên sân chơi, hầm xe và hành lang các tầng vào 18h00 tối thứ Sáu. Quý cư dân vui lòng đóng kín cửa sổ.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Thông báo phun thuốc diệt muỗi và côn trùng khu vực công cộng');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Lịch sục rửa và vệ sinh khử trùng bể nước sinh hoạt ngầm', 'Đội ngũ kỹ thuật sẽ tiến hành thau rửa bể nước ngầm và bể mái Block B trong ngày thứ Bảy. Áp lực nước có thể giảm nhẹ trong khung giờ 08:00 - 12:00.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Lịch sục rửa và vệ sinh khử trùng bể nước sinh hoạt ngầm');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Thông báo phát hành hóa đơn thu phí dịch vụ tháng 10/2026', 'Hóa đơn quản lý, điện, nước và phí gửi xe tháng 10/2026 đã được phát hành trên ứng dụng PKA-Home. Hạn thanh toán đến hết ngày 25/10/2026. Cư dân có thể thanh toán nhanh bằng mã VietQR tiện lợi.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Thông báo phát hành hóa đơn thu phí dịch vụ tháng 10/2026');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT '[KHẨN CẤP] Tạm ngừng vận hành thang máy TM-A01 để bảo trì định kỳ', 'Thang máy TM-A01 Block A sẽ tạm dừng hoạt động từ 13h30 đến 17h00 ngày mai để thay cáp tải và kiểm định an toàn kỹ thuật. Cư dân vui lòng di chuyển bằng thang máy TM-A02.', true, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = '[KHẨN CẤP] Tạm ngừng vận hành thang máy TM-A01 để bảo trì định kỳ');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT '[KHẨN CẤP] Diễn tập Phòng cháy Chữa cháy (PCCC) toàn khu dân cư', 'Ban Quản Lý phối hợp cùng Cảnh sát PCCC quận tổ chức diễn tập phương án chữa cháy & cứu nạn cứu hộ định kỳ vào 09h00 Chủ Nhật tuần này. Kính đề nghị toàn thể cư dân chủ động sắp xếp thời gian tham gia và tuân thủ hướng dẫn.', true, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = '[KHẨN CẤP] Diễn tập Phòng cháy Chữa cháy (PCCC) toàn khu dân cư');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'THÔNG BÁO KHẨN: Tạm ngừng cấp nước súc rửa bể ngầm định kỳ', 'Ban Quản lý xin thông báo tới toàn thể cư dân Tòa A và Tòa B về việc tạm ngừng cấp nước sinh hoạt từ 09:00 đến 14:00 ngày 20/09/2026 để kỹ thuật tiến hành súc rửa khử trùng bể chứa nước ngầm. Kính đề nghị cư dân chủ động tích trữ nước sinh hoạt trong khung giờ trên. Trân trọng cảm ơn sự phối hợp của Quý cư dân.', true, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'THÔNG BÁO KHẨN: Tạm ngừng cấp nước súc rửa bể ngầm định kỳ');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Lịch thu gom rác thải cồng kềnh định kỳ tháng 09/2026', 'Vào sáng Chủ nhật ngày 22/09/2026, Ban Quản lý phối hợp cùng đơn vị vệ sinh môi trường tổ chức thu gom đồ gỗ, nệm, vật dụng cồng kềnh tại khu vực tập kết rác hầm B1. Quý cư dân có nhu cầu thanh lý xin vui lòng mang xuống điểm tập kết trước 08:00 sáng.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Lịch thu gom rác thải cồng kềnh định kỳ tháng 09/2026');

INSERT INTO public.announcements (title, content, is_urgent, created_at, updated_at)
SELECT 'Kế hoạch phun khử trùng và diệt côn trùng khu vực công cộng', 'Nhằm đảm bảo vệ sinh môi trường sống và phòng ngừa dịch sốt xuất huyết, Ban Quản lý sẽ tiến hành phun thuốc diệt muỗi và côn trùng toàn bộ khuôn viên, tầng hầm và hành lang các tầng vào lúc 22:00 ngày 25/09/2026. Kính mong Quý cư dân đóng kín cửa ra vào và ban công trong thời gian trên.', false, NOW() - interval '2 days', NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.announcements WHERE title = 'Kế hoạch phun khử trùng và diệt côn trùng khu vực công cộng');
