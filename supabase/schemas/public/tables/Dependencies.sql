create table "public"."Dependencies" (
  "project_id"    bigint not null,
  "depends_on_id" bigint not null,
  constraint "Can't depend on itself" check ((project_id <> depends_on_id)),
  constraint "Dependencies_pkey" primary key (project_id, depends_on_id),
  constraint "Dependencies_depends_on_id_fkey" foreign key (depends_on_id) references public."Projects"(id) on update cascade on delete cascade,
  constraint "Dependencies_project_id_fkey" foreign key (project_id) references public."Projects"(id) on update cascade on delete cascade
);

alter table "public"."Dependencies"
  enable row level security;

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."Dependencies" to "anon", "authenticated", "postgres", "service_role";

comment on table "public"."Dependencies" is 'Project dependencies';

-- RLS Policies

create policy "anon_select_public_dependencies"
  on public."Dependencies"
  for select
  to anon
  using (
    exists (
      select 1 from public."Projects" p
      where p.id = "Dependencies".project_id
        and p."public" = true
    )
  );

create policy "authenticated_select_all_dependencies"
  on public."Dependencies"
  for select
  to authenticated
  using (true);

create policy "contributor_insert_dependencies"
  on public."Dependencies"
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Dependencies".project_id
        and u.authenticated_user = (select auth.uid())
    )
  );

create policy "contributor_update_dependencies"
  on public."Dependencies"
  for update
  to authenticated
  using (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Dependencies".project_id
        and u.authenticated_user = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Dependencies".project_id
        and u.authenticated_user = (select auth.uid())
    )
  );

create policy "contributor_delete_dependencies"
  on public."Dependencies"
  for delete
  to authenticated
  using (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Dependencies".project_id
        and u.authenticated_user = (select auth.uid())
    )
  );
