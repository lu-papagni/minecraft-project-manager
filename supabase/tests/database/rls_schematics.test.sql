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

-- Link schematics to projects via Builds
INSERT INTO public."Builds" (project, schematic)
VALUES
  (100, 10),  -- Castle belongs to public project
  (200, 20);  -- Bridge belongs to private project
-- Schematic 30 (Orphan) is not linked to any project

-- ============================================================
-- TEST: Anon can see schematics linked to public projects
-- ============================================================

SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM public."Schematics"),
  1,
  'anon sees only schematics linked to public projects'
);

SELECT is(
  (SELECT name FROM public."Schematics" LIMIT 1),
  'Castle',
  'anon sees the correct schematic (Castle)'
);

-- ============================================================
-- TEST: Authenticated user sees all schematics
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public."Schematics"),
  3,
  'authenticated user sees all schematics'
);

-- ============================================================
-- TEST: Any authenticated user can insert a schematic
-- ============================================================

SELECT lives_ok(
  $$INSERT INTO public."Schematics" (id, name, file_path) VALUES (40, 'Tower', '/schematics/tower.litematic')$$,
  'any authenticated user can create a schematic'
);

-- ============================================================
-- TEST: Contributor can update a schematic linked to their project
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

UPDATE public."Schematics" SET name = 'Grand Castle' WHERE id = 10;

RESET ROLE;

SELECT is(
  (SELECT name FROM public."Schematics" WHERE id = 10),
  'Grand Castle',
  'contributor can update a schematic linked to their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT update a schematic
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

UPDATE public."Schematics" SET name = 'Hacked Bridge' WHERE id = 20;

RESET ROLE;

SELECT is(
  (SELECT name FROM public."Schematics" WHERE id = 20),
  'Bridge',
  'non-contributor cannot update a schematic'
);

-- ============================================================
-- TEST: Non-contributor CANNOT delete a schematic
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

DELETE FROM public."Schematics" WHERE id = 10;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Schematics" WHERE id = 10),
  1,
  'non-contributor cannot delete a schematic'
);

SELECT * FROM finish();
ROLLBACK;
