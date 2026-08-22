BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, extensions;
SELECT plan(8);

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

-- ============================================================
-- TEST: Anon can see contributions for public projects only
-- ============================================================

SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM public."Contributions"),
  2,
  'anon sees contributions only for public projects'
);

SELECT ok(
  (SELECT count(*)::int FROM public."Contributions" WHERE project = 200) = 0,
  'anon cannot see contributions for private projects'
);

-- ============================================================
-- TEST: Authenticated user sees all contributions
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public."Contributions"),
  4,
  'authenticated user sees all contributions'
);

-- ============================================================
-- TEST: Contributor can add a new contributor
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT lives_ok(
  $$INSERT INTO public."Contributions" (project, "user") VALUES (100, 3)$$,
  'contributor can add a new contributor to their project'
);

-- ============================================================
-- TEST: Non-contributor CANNOT add a contributor
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
  $$INSERT INTO public."Contributions" (project, "user") VALUES (200, 3)$$,
  NULL,
  NULL,
  'non-contributor cannot add contributors to a project'
);

-- ============================================================
-- TEST: Contributor can remove a contributor
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

DELETE FROM public."Contributions" WHERE project = 100 AND "user" = 3;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Contributions" WHERE project = 100 AND "user" = 3),
  0,
  'contributor can remove a contributor'
);

-- ============================================================
-- TEST: Non-contributor CANNOT remove a contributor
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

DELETE FROM public."Contributions" WHERE project = 200 AND "user" = 2;

RESET ROLE;

SELECT is(
  (SELECT count(*)::int FROM public."Contributions" WHERE project = 200 AND "user" = 2),
  1,
  'non-contributor cannot remove contributors'
);

-- ============================================================
-- TEST: Anon CANNOT insert contributions
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT throws_ok(
  $$INSERT INTO public."Contributions" (project, "user") VALUES (100, 3)$$,
  NULL,
  NULL,
  'anon cannot add contributions'
);

SELECT * FROM finish();
ROLLBACK;
