BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, extensions;
SELECT plan(10);

-- ============================================================
-- SETUP: Create test users in auth.users and public.Users
-- ============================================================

-- Create auth users
INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, created_at, updated_at)
VALUES
  ('a1111111-1111-1111-1111-111111111111', 'owner@test.com', '{}', 'authenticated', 'authenticated', now(), now()),
  ('b2222222-2222-2222-2222-222222222222', 'contributor@test.com', '{}', 'authenticated', 'authenticated', now(), now()),
  ('c3333333-3333-3333-3333-333333333333', 'outsider@test.com', '{}', 'authenticated', 'authenticated', now(), now());

-- Create public.Users rows
INSERT INTO public."Users" (id, authenticated_user, username)
VALUES
  (1, 'a1111111-1111-1111-1111-111111111111', 'owner_user'),
  (2, 'b2222222-2222-2222-2222-222222222222', 'contributor_user'),
  (3, 'c3333333-3333-3333-3333-333333333333', 'outsider_user');

-- Create projects (bypass RLS as postgres)
INSERT INTO public."Projects" (id, name, description, created_by, "public")
VALUES
  (100, 'Public Project', 'A public project', 1, true),
  (200, 'Private Project', 'A private project', 1, false);

-- Create contributions
-- Note: (100, 1) and (200, 1) are auto-created by trg_auto_contributor
INSERT INTO public."Contributions" (project, "user")
VALUES
  (100, 2),  -- contributor_user contributes to public project
  (200, 2);  -- contributor_user contributes to private project

-- ============================================================
-- TEST: Anon can only see public projects
-- ============================================================

SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM public."Projects"),
  1,
  'anon can only see 1 project (the public one)'
);

SELECT is(
  (SELECT name FROM public."Projects" LIMIT 1),
  'Public Project',
  'anon sees the public project'
);

-- ============================================================
-- TEST: Authenticated user sees ALL projects
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public."Projects"),
  2,
  'authenticated outsider sees all projects (public + private)'
);

-- ============================================================
-- TEST: Authenticated user can INSERT a project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT lives_ok(
  $$INSERT INTO public."Projects" (id, name, description, created_by, "public") VALUES (300, 'New Project', 'Created by outsider', 3, true)$$,
  'authenticated user can create a project'
);

-- ============================================================
-- TEST: Contributor can UPDATE a project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

UPDATE public."Projects" SET description = 'Updated by contributor' WHERE id = 100;

SELECT is(
  (SELECT description FROM public."Projects" WHERE id = 100),
  'Updated by contributor',
  'contributor can update a project they contribute to'
);

-- ============================================================
-- TEST: Non-contributor CANNOT update a project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

UPDATE public."Projects" SET description = 'Hacked!' WHERE id = 100;

-- Reset to check the actual value
RESET ROLE;

SELECT is(
  (SELECT description FROM public."Projects" WHERE id = 100),
  'Updated by contributor',
  'non-contributor cannot update a project'
);

-- ============================================================
-- TEST: Owner can DELETE their project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT lives_ok(
  $$DELETE FROM public."Projects" WHERE id = 100$$,
  'owner can delete their project'
);

-- ============================================================
-- TEST: Non-owner CANNOT delete a project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

DELETE FROM public."Projects" WHERE id = 200;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Projects" WHERE id = 200),
  1,
  'non-owner cannot delete a project'
);

-- ============================================================
-- TEST: Anon CANNOT insert a project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT throws_ok(
  $$INSERT INTO public."Projects" (id, name, description, created_by, "public") VALUES (400, 'Anon Project', 'nope', NULL, true)$$,
  NULL,
  NULL,
  'anon cannot insert a project'
);

-- ============================================================
-- TEST: Anon CANNOT update a project
-- ============================================================

UPDATE public."Projects" SET description = 'Hacked by anon!' WHERE id = 200;

RESET ROLE;

SELECT is(
  (SELECT description FROM public."Projects" WHERE id = 200),
  'A private project',
  'anon cannot update a project'
);

SELECT * FROM finish();
ROLLBACK;
