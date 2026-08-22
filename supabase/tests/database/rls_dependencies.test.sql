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
  (200, 'Private Project', 'A private project', 1, false),
  (300, 'Public Sub-Project', 'A public dependency', 1, true);

-- Note: (100, 1), (200, 1), and (300, 1) are auto-created by trg_auto_contributor
INSERT INTO public."Contributions" (project, "user")
VALUES
  (100, 2),
  (200, 2);

INSERT INTO public."Dependencies" (project_id, depends_on_id)
VALUES
  (100, 200),  -- public project depends on private project
  (100, 300),  -- public project depends on public sub-project
  (200, 300);  -- private project depends on public sub-project

-- ============================================================
-- TEST: Anon sees dependencies only where project_id is public
-- ============================================================

SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM public."Dependencies"),
  2,
  'anon sees dependencies where project_id is public (top-level only)'
);

SELECT ok(
  (SELECT count(*)::int FROM public."Dependencies" WHERE project_id = 200) = 0,
  'anon cannot see dependencies of private projects'
);

-- ============================================================
-- TEST: Authenticated user sees all dependencies
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public."Dependencies"),
  3,
  'authenticated user sees all dependencies'
);

-- ============================================================
-- TEST: Contributor can insert a dependency
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT lives_ok(
  $$INSERT INTO public."Dependencies" (project_id, depends_on_id) VALUES (200, 100)$$,
  'contributor can add a dependency to their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT insert a dependency
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
  $$INSERT INTO public."Dependencies" (project_id, depends_on_id) VALUES (100, 300)$$,
  NULL,
  NULL,
  'non-contributor cannot add a dependency'
);

-- ============================================================
-- TEST: Contributor can delete a dependency
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

DELETE FROM public."Dependencies" WHERE project_id = 100 AND depends_on_id = 200;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Dependencies" WHERE project_id = 100 AND depends_on_id = 200),
  0,
  'contributor can delete a dependency from their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT delete a dependency
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

DELETE FROM public."Dependencies" WHERE project_id = 100 AND depends_on_id = 300;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Dependencies" WHERE project_id = 100 AND depends_on_id = 300),
  1,
  'non-contributor cannot delete a dependency'
);

SELECT * FROM finish();
ROLLBACK;
