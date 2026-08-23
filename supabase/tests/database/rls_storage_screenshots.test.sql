BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, storage, extensions;
SELECT plan(6);

-- ============================================================
-- SETUP
-- ============================================================

INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, created_at, updated_at)
VALUES
  ('a1111111-1111-1111-1111-111111111111', 'owner@test.com', '{}', 'authenticated', 'authenticated', now(), now()),
  ('b2222222-2222-2222-2222-222222222222', 'contributor@test.com', '{}', 'authenticated', 'authenticated', now(), now()),
  ('c3333333-3333-3333-3333-333333333333', 'outsider@test.com', '{}', 'authenticated', 'authenticated', now(), now());

INSERT INTO public."Users" (id, authenticated_user, username)
VALUES
  (1, 'a1111111-1111-1111-1111-111111111111', 'owner_user'),
  (2, 'b2222222-2222-2222-2222-222222222222', 'contributor_user'),
  (3, 'c3333333-3333-3333-3333-333333333333', 'outsider_user');

INSERT INTO public."Projects" (id, name, description, created_by, "public")
VALUES
  (100, 'Public Project', 'A public project', 1, true),
  (200, 'Private Project', 'A private project', 1, false);

-- Note: (100, 1) and (200, 1) are auto-created by trg_auto_contributor
INSERT INTO public."Contributions" (project, "user")
VALUES
  (100, 2),
  (200, 2);

-- Seed storage objects in the screenshots bucket
-- Path format: {project_id}/{uuid}.{ext}
INSERT INTO storage.objects (id, bucket_id, name, owner)
VALUES
  (gen_random_uuid(), 'screenshots', '100/img1.png', 'a1111111-1111-1111-1111-111111111111'),
  (gen_random_uuid(), 'screenshots', '200/img2.png', 'b2222222-2222-2222-2222-222222222222');

-- ============================================================
-- TEST: Contributor can INSERT screenshots for their project
-- ============================================================

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT lives_ok(
  $$INSERT INTO storage.objects (id, bucket_id, name, owner) VALUES (gen_random_uuid(), 'screenshots', '100/new-screenshot.png', 'b2222222-2222-2222-2222-222222222222')$$,
  'contributor can upload a screenshot to their project folder'
);

-- ============================================================
-- TEST: Non-contributor CANNOT INSERT screenshots
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
  $$INSERT INTO storage.objects (id, bucket_id, name, owner) VALUES (gen_random_uuid(), 'screenshots', '200/hacked.png', 'c3333333-3333-3333-3333-333333333333')$$,
  NULL, NULL,
  'non-contributor cannot upload a screenshot to a project they do not contribute to'
);

-- ============================================================
-- TEST: Contributor can UPDATE screenshots in their project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

UPDATE storage.objects
  SET metadata = '{"updated": true}'::jsonb
  WHERE bucket_id = 'screenshots' AND name = '100/img1.png';

RESET ROLE;

SELECT is(
  (SELECT (metadata->>'updated')::text FROM storage.objects WHERE bucket_id = 'screenshots' AND name = '100/img1.png'),
  'true',
  'contributor can update a screenshot in their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT UPDATE screenshots
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

UPDATE storage.objects
  SET metadata = '{"hacked": true}'::jsonb
  WHERE bucket_id = 'screenshots' AND name = '200/img2.png';

RESET ROLE;

SELECT is(
  (SELECT metadata->>'hacked' FROM storage.objects WHERE bucket_id = 'screenshots' AND name = '200/img2.png'),
  NULL,
  'non-contributor cannot update a screenshot they do not own'
);

-- ============================================================
-- TEST: Contributor can DELETE screenshots in their project
-- ============================================================

RESET ROLE;
SET LOCAL "storage.allow_delete_query" TO 'true';
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

DELETE FROM storage.objects WHERE bucket_id = 'screenshots' AND name = '100/img1.png';

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'screenshots' AND name = '100/img1.png'),
  0,
  'contributor can delete a screenshot in their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT DELETE screenshots
-- ============================================================

RESET ROLE;
SET LOCAL "storage.allow_delete_query" TO 'true';
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

DELETE FROM storage.objects WHERE bucket_id = 'screenshots' AND name = '200/img2.png';

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'screenshots' AND name = '200/img2.png'),
  1,
  'non-contributor cannot delete a screenshot'
);

SELECT * FROM finish();
ROLLBACK;
