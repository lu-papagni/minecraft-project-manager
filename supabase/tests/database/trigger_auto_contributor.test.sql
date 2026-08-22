BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, extensions;
SELECT plan(3);

-- ============================================================
-- SETUP
-- ============================================================

INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, created_at, updated_at)
VALUES
  ('a1111111-1111-1111-1111-111111111111', 'owner@test.com', '{}', 'authenticated', 'authenticated', now(), now());

INSERT INTO public."Users" (id, authenticated_user, username)
VALUES
  (1, 'a1111111-1111-1111-1111-111111111111', 'owner_user');

-- ============================================================
-- TEST: Creating a project auto-inserts owner as contributor
-- ============================================================

-- Insert a project as postgres (simulating what the app does after RLS passes)
INSERT INTO public."Projects" (id, name, description, created_by, "public")
VALUES (100, 'Auto Contrib Project', 'Testing trigger', 1, true);

SELECT is(
  (SELECT count(*)::int FROM public."Contributions" WHERE project = 100 AND "user" = 1),
  1,
  'trigger auto-inserts owner as contributor on project creation'
);

-- ============================================================
-- TEST: Creating another project also gets auto-contribution
-- ============================================================

INSERT INTO public."Projects" (id, name, description, created_by, "public")
VALUES (200, 'Second Project', 'Another test', 1, false);

SELECT is(
  (SELECT count(*)::int FROM public."Contributions" WHERE project = 200 AND "user" = 1),
  1,
  'trigger works for multiple projects'
);

-- ============================================================
-- TEST: Total contributions match expected count
-- ============================================================

SELECT is(
  (SELECT count(*)::int FROM public."Contributions"),
  2,
  'only auto-created contributions exist (no duplicates)'
);

SELECT * FROM finish();
ROLLBACK;
