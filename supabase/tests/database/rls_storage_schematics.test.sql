BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, storage, extensions;
SELECT plan(9);

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

INSERT INTO public."Schematics" (id, name, file_path)
VALUES
  (10, 'Castle', 'castle.litematic'),
  (20, 'Bridge', 'bridge.litematic'),
  (30, 'Orphan', 'orphan.litematic');

INSERT INTO public."Builds" (project, schematic)
VALUES
  (100, 10),  -- Castle belongs to public project
  (200, 20);  -- Bridge belongs to private project

-- Seed storage objects in the schematics bucket
INSERT INTO storage.objects (id, bucket_id, name, owner)
VALUES
  (gen_random_uuid(), 'schematics', 'castle.litematic', 'a1111111-1111-1111-1111-111111111111'),
  (gen_random_uuid(), 'schematics', 'bridge.litematic', 'a1111111-1111-1111-1111-111111111111'),
  (gen_random_uuid(), 'schematics', 'orphan.litematic', 'a1111111-1111-1111-1111-111111111111');

-- ============================================================
-- TEST: Authenticated user can SELECT all schematics objects
-- ============================================================

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'schematics'),
  3,
  'authenticated user can see all schematics storage objects'
);

-- ============================================================
-- TEST: Anon can only SELECT schematics linked to public projects
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'schematics'),
  1,
  'anon sees only schematics linked to public projects'
);

SELECT is(
  (SELECT name FROM storage.objects WHERE bucket_id = 'schematics' LIMIT 1),
  'castle.litematic',
  'anon sees the correct schematics object (castle)'
);

-- ============================================================
-- TEST: Authenticated user can INSERT with .litematic extension
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT lives_ok(
  $$INSERT INTO storage.objects (id, bucket_id, name, owner) VALUES (gen_random_uuid(), 'schematics', 'new-file.litematic', 'c3333333-3333-3333-3333-333333333333')$$,
  'authenticated user can upload a .litematic file'
);

-- ============================================================
-- TEST: Authenticated user CANNOT INSERT non-.litematic extension
-- ============================================================

SELECT throws_ok(
  $$INSERT INTO storage.objects (id, bucket_id, name, owner) VALUES (gen_random_uuid(), 'schematics', 'evil.zip', 'c3333333-3333-3333-3333-333333333333')$$,
  NULL, NULL,
  'authenticated user cannot upload a non-.litematic file'
);

-- ============================================================
-- TEST: Contributor can UPDATE schematics linked to their project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'schematics' AND name = 'castle.litematic'),
  1,
  'contributor can see castle.litematic before update test'
);

UPDATE storage.objects
  SET metadata = '{"updated": true}'::jsonb
  WHERE bucket_id = 'schematics' AND name = 'castle.litematic';

RESET ROLE;

SELECT is(
  (SELECT (metadata->>'updated')::text FROM storage.objects WHERE bucket_id = 'schematics' AND name = 'castle.litematic'),
  'true',
  'contributor can update a schematics object linked to their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT UPDATE schematics
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

UPDATE storage.objects
  SET metadata = '{"hacked": true}'::jsonb
  WHERE bucket_id = 'schematics' AND name = 'bridge.litematic';

RESET ROLE;

SELECT is(
  (SELECT metadata->>'hacked' FROM storage.objects WHERE bucket_id = 'schematics' AND name = 'bridge.litematic'),
  NULL,
  'non-contributor cannot update a schematics object'
);

-- ============================================================
-- TEST: Non-contributor CANNOT DELETE schematics
-- ============================================================

RESET ROLE;
SET LOCAL "storage.allow_delete_query" TO 'true';
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

DELETE FROM storage.objects WHERE bucket_id = 'schematics' AND name = 'castle.litematic';

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM storage.objects WHERE bucket_id = 'schematics' AND name = 'castle.litematic'),
  1,
  'non-contributor cannot delete a schematics object'
);

SELECT * FROM finish();
ROLLBACK;
