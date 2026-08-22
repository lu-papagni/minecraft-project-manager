BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, extensions;
SELECT plan(7);

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
  (10, 'Castle', '/schematics/castle.litematic'),
  (20, 'Bridge', '/schematics/bridge.litematic'),
  (30, 'Orphan', '/schematics/orphan.litematic');

INSERT INTO public."Builds" (project, schematic, coord_x, coord_y, coord_z)
VALUES
  (100, 10, 0, 64, 0),
  (200, 20, 100, 64, 100);

-- ============================================================
-- TEST: Anon can see builds for public projects only
-- ============================================================

SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM public."Builds"),
  1,
  'anon sees builds only for public projects'
);

SELECT is(
  (SELECT schematic::int FROM public."Builds" LIMIT 1),
  10,
  'anon sees the correct build (Castle in Public Project)'
);

-- ============================================================
-- TEST: Authenticated user sees all builds
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public."Builds"),
  2,
  'authenticated user sees all builds'
);

-- ============================================================
-- TEST: Contributor can insert a build
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT lives_ok(
  $$INSERT INTO public."Builds" (project, schematic, coord_x, coord_y, coord_z) VALUES (100, 30, 50, 64, 50)$$,
  'contributor can insert a build into their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT insert a build
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
  $$INSERT INTO public."Builds" (project, schematic, coord_x, coord_y, coord_z) VALUES (200, 30, 50, 64, 50)$$,
  NULL,
  NULL,
  'non-contributor cannot insert a build'
);

-- ============================================================
-- TEST: Contributor can delete a build
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

DELETE FROM public."Builds" WHERE project = 100 AND schematic = 30;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Builds" WHERE project = 100 AND schematic = 30),
  0,
  'contributor can delete a build from their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT delete a build
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

DELETE FROM public."Builds" WHERE project = 200 AND schematic = 20;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Builds" WHERE project = 200 AND schematic = 20),
  1,
  'non-contributor cannot delete a build'
);

SELECT * FROM finish();
ROLLBACK;
