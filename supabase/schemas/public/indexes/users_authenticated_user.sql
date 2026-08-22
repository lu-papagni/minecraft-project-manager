-- Index for RLS policy lookups: auth.uid() → Users.authenticated_user
create index idx_users_authenticated_user on public."Users" (authenticated_user);
