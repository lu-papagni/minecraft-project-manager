-- Storage RLS Policies
-- These policies secure the storage.objects table for the schematics and screenshots buckets.
-- pgdelta does NOT support the storage schema, so these must live in a migration file.

-- ============================================================
-- SCHEMATICS BUCKET (private)
-- ============================================================

-- Any authenticated user can view all schematics
create policy "authenticated_select_schematics"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'schematics');

-- Anon can only view schematics linked to a public project
create policy "anon_select_public_schematics_storage"
  on storage.objects
  for select
  to anon
  using (
    bucket_id = 'schematics'
    and exists (
      select 1 from public."Schematics" s
      join public."Builds" b on b.schematic = s.id
      join public."Projects" p on p.id = b.project
      where s.file_path = objects.name
        and p."public" = true
    )
  );

-- Any authenticated user can upload, but only .litematic files
create policy "authenticated_insert_schematics_storage"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'schematics'
    and storage.extension(objects.name) = 'litematic'
  );

-- Only contributors of a linked project can update (extension check preserved)
create policy "contributor_update_schematics_storage"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'schematics'
    and exists (
      select 1 from public."Schematics" s
      join public."Builds" b on b.schematic = s.id
      join public."Contributions" c on c.project = b.project
      join public."Users" u on u.id = c."user"
      where s.file_path = objects.name
        and u.authenticated_user = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'schematics'
    and storage.extension(objects.name) = 'litematic'
  );

-- Only contributors of a linked project can delete
create policy "contributor_delete_schematics_storage"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'schematics'
    and exists (
      select 1 from public."Schematics" s
      join public."Builds" b on b.schematic = s.id
      join public."Contributions" c on c.project = b.project
      join public."Users" u on u.id = c."user"
      where s.file_path = objects.name
        and u.authenticated_user = (select auth.uid())
    )
  );

-- ============================================================
-- SCREENSHOTS BUCKET (public)
-- ============================================================

-- Public bucket: anyone can view (needed for UPDATE/DELETE to find rows via RLS)
create policy "anyone_select_screenshots"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'screenshots');

-- Contributor can upload screenshots to their project folder
create policy "contributor_insert_screenshots"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'screenshots'
    and exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = (storage.foldername(objects.name))[1]::bigint
        and u.authenticated_user = (select auth.uid())
    )
  );

-- Contributor can update screenshots in their project folder
create policy "contributor_update_screenshots"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'screenshots'
    and exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = (storage.foldername(objects.name))[1]::bigint
        and u.authenticated_user = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'screenshots'
    and exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = (storage.foldername(objects.name))[1]::bigint
        and u.authenticated_user = (select auth.uid())
    )
  );

-- Contributor can delete screenshots in their project folder
create policy "contributor_delete_screenshots"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'screenshots'
    and exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = (storage.foldername(objects.name))[1]::bigint
        and u.authenticated_user = (select auth.uid())
    )
  );
