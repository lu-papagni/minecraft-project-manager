BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path TO public, extensions;
SELECT plan(6);

-- ============================================================
-- SETUP
-- ============================================================

INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, created_at, updated_at)
VALUES
  ('a1111111-1111-1111-1111-111111111111', 'owner@test.com', '{}', 'authenticated', 'authenticated', now(), now()),
  ('b2222222-2222-2222-2222-222222222222', 'other@test.com', '{}', 'authenticated', 'authenticated', now(), now());

INSERT INTO public."Users" (id, authenticated_user, username)
VALUES
  (1, 'a1111111-1111-1111-1111-111111111111', 'owner_user'),
  (2, 'b2222222-2222-2222-2222-222222222222', 'other_user');

-- ============================================================
-- TEST: Anon can see all users (public profiles)
-- ============================================================

SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

SELECT is(
  (SELECT count(*)::int FROM public."Users"),
  2,
  'anon can see all user profiles'
);

-- ============================================================
-- TEST: Authenticated can see all users
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT is(
  (SELECT count(*)::int FROM public."Users"),
  2,
  'authenticated user can see all user profiles'
);

-- ============================================================
-- TEST: User can update their own profile
-- ============================================================

UPDATE public."Users" SET username = 'new_username' WHERE id = 1;

SELECT is(
  (SELECT username FROM public."Users" WHERE id = 1),
  'new_username',
  'user can update their own profile'
);

-- ============================================================
-- TEST: User CANNOT update another user's profile
-- ============================================================

UPDATE public."Users" SET username = 'hacked' WHERE id = 2;

RESET ROLE;

SELECT is(
  (SELECT username FROM public."Users" WHERE id = 2),
  'other_user',
  'user cannot update another users profile'
);

-- ============================================================
-- TEST: User CANNOT change their authenticated_user field
-- ============================================================

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
  $$UPDATE public."Users" SET authenticated_user = 'b2222222-2222-2222-2222-222222222222' WHERE id = 1$$,
  NULL,
  NULL,
  'user cannot change their authenticated_user field'
);

-- ============================================================
-- TEST: Anon CANNOT update any user
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;
SET LOCAL "request.jwt.claims" TO '{}';

UPDATE public."Users" SET username = 'anon_hacked' WHERE id = 1;

RESET ROLE;

SELECT is(
  (SELECT username FROM public."Users" WHERE id = 1),
  'new_username',
  'anon cannot update any user profile'
);

SELECT * FROM finish();
ROLLBACK;
