create type "public"."dimension" as enum (
  'overworld',
  'nether',
  'end'
);

alter table "public"."Builds"
  add column "dimension" public.dimension not null default 'overworld'::public.dimension;

grant usage on type "public"."dimension" to "postgres";
