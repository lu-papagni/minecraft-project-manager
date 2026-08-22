create or replace function public.auto_add_owner_as_contributor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public."Contributions" (project, "user")
  values (NEW.id, NEW.created_by);
  return NEW;
end;
$$;

revoke all on function public.auto_add_owner_as_contributor() from public;
revoke execute on function public.auto_add_owner_as_contributor() from anon, authenticated, service_role;
