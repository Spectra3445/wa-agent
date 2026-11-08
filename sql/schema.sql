-- agent: throwaway remote-inspection tables (public schema, agent_ prefix)
create table if not exists public.agent_devices (
  id         uuid primary key default gen_random_uuid(),
  run        text not null,
  label      text,
  ua         text,
  platform   text,
  vendor     text,
  screen     text,
  dpr        numeric,
  tz         text,
  lang       text,
  cores      int,
  mem        numeric,
  battery    text,
  conn       text,
  standalone boolean default false,
  caps       jsonb,
  first_seen timestamptz default now(),
  last_seen  timestamptz default now()
);

create table if not exists public.agent_events (
  id        bigserial primary key,
  run       text not null,
  device_id uuid,
  kind      text not null,
  payload   jsonb,
  at        timestamptz default now()
);

create table if not exists public.agent_commands (
  id        bigserial primary key,
  run       text not null,
  device_id uuid,
  name      text not null,
  args      jsonb,
  at        timestamptz default now()
);

create index if not exists agent_devices_run_seen on public.agent_devices (run, last_seen desc);
create index if not exists agent_events_run_at     on public.agent_events  (run, at desc);
create index if not exists agent_events_device_at  on public.agent_events  (device_id, at desc);
create index if not exists agent_cmd_device_at     on public.agent_commands (device_id, at desc);

create or replace function public.agent_trim() returns trigger language plpgsql as $$
begin
  if (select count(*) from public.agent_events where device_id = new.device_id) % 200 = 0 then
    delete from public.agent_events
     where device_id = new.device_id
       and id not in (select id from public.agent_events where device_id = new.device_id order by id desc limit 500);
    delete from public.agent_commands where at < now() - interval '2 days';
  end if;
  return new;
end $$;

drop trigger if exists agent_events_trim on public.agent_events;
create trigger agent_events_trim after insert on public.agent_events for each row execute function public.agent_trim();

grant all on public.agent_devices, public.agent_events, public.agent_commands to anon, authenticated, service_role;
grant all on sequence public.agent_events_id_seq, public.agent_commands_id_seq to anon, authenticated, service_role;

alter table public.agent_devices  enable row level security;
alter table public.agent_events   enable row level security;
alter table public.agent_commands enable row level security;

drop policy if exists agent_run_devices  on public.agent_devices;
drop policy if exists agent_run_events   on public.agent_events;
drop policy if exists agent_run_commands on public.agent_commands;

create policy agent_run_devices on public.agent_devices for all to anon, authenticated
  using (run = coalesce(current_setting('request.headers', true)::json ->> 'x-run', run))
  with check (run = coalesce(current_setting('request.headers', true)::json ->> 'x-run', run));

create policy agent_run_events on public.agent_events for all to anon, authenticated
  using (run = coalesce(current_setting('request.headers', true)::json ->> 'x-run', run))
  with check (run = coalesce(current_setting('request.headers', true)::json ->> 'x-run', run));

create policy agent_run_commands on public.agent_commands for all to anon, authenticated
  using (run = coalesce(current_setting('request.headers', true)::json ->> 'x-run', run))
  with check (run = coalesce(current_setting('request.headers', true)::json ->> 'x-run', run));

do $$
declare t text;
begin
  foreach t in array array['agent_events', 'agent_commands', 'agent_devices'] loop
    if not exists (select 1 from pg_publication_tables
                    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

alter table public.agent_events replica identity full;
alter table public.agent_commands replica identity full;
alter table public.agent_devices replica identity full;
