create table "public"."Contributions" (
  "created_at" timestamp with time zone not null default now(),
  "project"    bigint                   not null,
  "user"       bigint                   not null,
  constraint "Contributions_pkey" primary key (project, "user"),
  constraint "Contributions_project_fkey" foreign key (project) references public."Projects"(id) on update cascade on delete cascade,
  constraint "Contributions_user_fkey" foreign key ("user") references public."Users"(id) on update cascade on delete cascade
);

alter table "public"."Contributions"
  enable row level security;

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."Contributions" to "anon", "authenticated", "postgres", "service_role";

comment on table "public"."Contributions" is 'Users who have engaged in a project';

-- RLS Policies

create policy "anon_select_public_contributions"
  on public."Contributions"
  for select
  to anon
  using (
    exists (
      select 1 from public."Projects" p
      where p.id = "Contributions".project
        and p."public" = true
    )
  );

create policy "authenticated_select_all_contributions"
  on public."Contributions"
  for select
  to authenticated
  using (true);

create policy "contributor_insert_contributions"
  on public."Contributions"
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Contributions".project
        and u.authenticated_user = (select auth.uid())
    )
  );

create policy "contributor_delete_contributions"
  on public."Contributions"
  for delete
  to authenticated
  using (
    exists (
      select 1 from public."Contributions" c
      join public."Users" u on u.id = c."user"
      where c.project = "Contributions".project
        and u.authenticated_user = (select auth.uid())
    )
  );
