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
