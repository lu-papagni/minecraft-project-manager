create table "public"."Builds" (
  "created_at" timestamp with time zone not null default now(),
  "project"    bigint                   not null,
  "schematic"  bigint                   not null,
  "coord_x"    real,
  "coord_y"    real,
  "coord_z"    real,
  "dimension"  "public"."dimension"   not null default 'overworld'::"public"."dimension",
  constraint "Builds_pkey" primary key (project, schematic),
  constraint "Builds_project_fkey" foreign key (project) references public."Projects"(id) on update cascade on delete cascade,
  constraint "Builds_schematic_fkey" foreign key (schematic) references public."Schematics"(id) on update cascade on delete cascade
);

alter table "public"."Builds"
  enable row level security;

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."Builds" to "anon", "authenticated", "postgres", "service_role";

comment on table "public"."Builds" is 'Schematics used in projects';

-- RLS Policies

create policy "anon_select_public_builds"
  on public."Builds"
  for select
  to anon
  using (
    exists (
      select 1 from public."Projects" p
      where p.id = "Builds".project
        and p."public" = true
    )
  );

create policy "authenticated_select_all_builds"
  on public."Builds"
  for select
  to authenticated
  using (true);

create policy "contributor_insert_builds"
  on public."Builds"
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Builds".project
        and u.authenticated_user = (select auth.uid())
    )
  );

create policy "contributor_update_builds"
  on public."Builds"
  for update
  to authenticated
  using (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Builds".project
        and u.authenticated_user = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Builds".project
        and u.authenticated_user = (select auth.uid())
    )
  );

create policy "contributor_delete_builds"
  on public."Builds"
  for delete
  to authenticated
  using (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Builds".project
        and u.authenticated_user = (select auth.uid())
    )
  );
