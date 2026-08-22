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
