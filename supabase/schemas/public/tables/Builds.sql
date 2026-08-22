create table "public"."Builds" (
  "created_at" timestamp with time zone not null default now(),
  "project"    bigint                   not null,
  "schematic"  bigint                   not null,
  "coord_x"    real,
  "coord_y"    real,
  "coord_z"    real,
  constraint "Builds_pkey" primary key (project, schematic),
  constraint "Builds_project_fkey" foreign key (project) references public."Projects"(id) on update cascade on delete cascade,
  constraint "Builds_schematic_fkey" foreign key (schematic) references public."Schematics"(id) on update cascade on delete cascade
);

alter table "public"."Builds"
  enable row level security;

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."Builds" to "anon", "authenticated", "postgres", "service_role";

comment on table "public"."Builds" is 'Schematics used in projects';
