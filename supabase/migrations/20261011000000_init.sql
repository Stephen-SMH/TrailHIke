-- TrailMark: nearby hikers, SOS incidents, and per-incident chat.
--
-- Privacy rules baked in here, not in the app:
--  * Nobody can read the presence table directly. Others only get fuzzed
--    positions (about 110 m grid) from nearby_hikers().
--  * An SOS shows its exact position, but only to people within range, and
--    only while it is open.
--  * An incident chat is readable only by the victim and those who joined.

create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------- tables

create table public.presence (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 40),
  geom       extensions.geography(Point, 4326) not null,
  updated_at timestamptz not null default now()
);
create index presence_geom_idx on public.presence using gist (geom);

create table public.incidents (
  id          uuid primary key default gen_random_uuid(),
  victim_id   uuid not null references auth.users (id) on delete cascade,
  victim_name text not null check (char_length(victim_name) between 1 and 40),
  geom        extensions.geography(Point, 4326) not null,
  note        text not null default '' check (char_length(note) <= 280),
  status      text not null default 'open' check (status in ('open', 'resolved')),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);
create index incidents_geom_idx on public.incidents using gist (geom);
create index incidents_open_idx on public.incidents (status, created_at desc);

create table public.incident_responders (
  incident_id uuid not null references public.incidents (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  joined_at   timestamptz not null default now(),
  primary key (incident_id, user_id)
);

create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.incidents (id) on delete cascade,
  sender_id   uuid not null references auth.users (id) on delete cascade,
  sender_name text not null check (char_length(sender_name) between 1 and 40),
  body        text not null check (char_length(body) between 1 and 1000),
  created_at  timestamptz not null default now()
);
create index messages_incident_idx on public.messages (incident_id, created_at);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_id uuid not null,
  incident_id uuid,
  reason      text not null check (char_length(reason) between 1 and 500),
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------- constants

-- One place for the numbers the app relies on.
create function public.presence_ttl() returns interval
  language sql immutable as $$ select interval '30 minutes' $$;

-- ------------------------------------------------------------------- RLS

alter table public.presence            enable row level security;
alter table public.incidents           enable row level security;
alter table public.incident_responders enable row level security;
alter table public.messages            enable row level security;
alter table public.reports             enable row level security;

-- presence: no direct access at all (use the functions below).

-- Helper: is the caller the victim or a responder of this incident?
create function public.is_participant(p_incident uuid) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.incidents i
    where i.id = p_incident
      and (i.victim_id = (select auth.uid())
           or exists (select 1 from public.incident_responders r
                      where r.incident_id = i.id
                        and r.user_id = (select auth.uid())))
  )
$$;

-- Helper: is this incident open and within range of the caller's last position?
create function public.in_range_of_open(p_incident uuid) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.incidents i
    join public.presence p on p.user_id = (select auth.uid())
    where i.id = p_incident
      and i.status = 'open'
      and p.updated_at > now() - public.presence_ttl()
      and extensions.st_dwithin(p.geom, i.geom, 5000)
  )
$$;

-- incidents: victim, participants, and people in range of an open SOS.
create policy incidents_select on public.incidents for select to authenticated
  using (
    victim_id = (select auth.uid())
    or public.is_participant(id)
    or public.in_range_of_open(id)
  );

-- responders: see who is on an incident you can see.
create policy responders_select on public.incident_responders
  for select to authenticated
  using (public.is_participant(incident_id));

-- messages: participants only, and only as yourself.
create policy messages_select on public.messages for select to authenticated
  using (public.is_participant(incident_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.is_participant(incident_id)
    and exists (select 1 from public.incidents i
                where i.id = incident_id and i.status = 'open')
  );

-- reports: write-only for users (moderators read them in the dashboard).
create policy reports_insert on public.reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));

-- ------------------------------------------------------------- functions
-- All writes go through these. They run as the table owner, so each one
-- checks auth.uid() itself.

create function public.set_presence(p_lat double precision, p_lon double precision, p_name text)
  returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'not signed in'; end if;
  if p_lat not between -90 and 90 or p_lon not between -180 and 180 then
    raise exception 'bad position';
  end if;
  insert into public.presence (user_id, name, geom, updated_at)
  values ((select auth.uid()), left(trim(p_name), 40),
          extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography,
          now())
  on conflict (user_id) do update
    set name = excluded.name, geom = excluded.geom, updated_at = now();
end $$;

create function public.clear_presence() returns void
  language sql security definer set search_path = '' as $$
  delete from public.presence where user_id = (select auth.uid())
$$;

-- Nearby hikers with positions snapped to ~110 m, never exact.
create function public.nearby_hikers(p_lat double precision, p_lon double precision, p_radius_m double precision)
  returns table (id uuid, name text, lat double precision, lon double precision, updated_at timestamptz)
  language sql stable security definer set search_path = '' as $$
  select p.user_id,
         split_part(p.name, ' ', 1),
         round(extensions.st_y(p.geom::extensions.geometry)::numeric, 3)::double precision,
         round(extensions.st_x(p.geom::extensions.geometry)::numeric, 3)::double precision,
         p.updated_at
  from public.presence p
  where p.user_id <> (select auth.uid())
    and p.updated_at > now() - public.presence_ttl()
    and extensions.st_dwithin(p.geom,
          extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography,
          least(p_radius_m, 20000))
  order by p.geom operator(extensions.<->)
          extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography
  limit 50
$$;

create type public.incident_row as (
  id uuid, victim_id uuid, victim_name text, lat double precision, lon double precision,
  note text, status text, created_at timestamptz, responder_ids uuid[]
);

-- Open SOS within range, for the caller to answer. Exact position, by design.
create function public.nearby_incidents(p_lat double precision, p_lon double precision, p_radius_m double precision)
  returns setof public.incident_row
  language sql stable security definer set search_path = '' as $$
  select i.id, i.victim_id, i.victim_name,
         extensions.st_y(i.geom::extensions.geometry),
         extensions.st_x(i.geom::extensions.geometry),
         i.note, i.status, i.created_at,
         coalesce((select array_agg(r.user_id) from public.incident_responders r
                   where r.incident_id = i.id), '{}')
  from public.incidents i
  where i.status = 'open'
    and i.victim_id <> (select auth.uid())
    and i.created_at > now() - interval '24 hours'
    and extensions.st_dwithin(i.geom,
          extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography,
          least(p_radius_m, 20000))
  order by i.created_at desc
  limit 20
$$;

create function public.my_incident(p_id uuid)
  returns setof public.incident_row
  language sql stable security definer set search_path = '' as $$
  select i.id, i.victim_id, i.victim_name,
         extensions.st_y(i.geom::extensions.geometry),
         extensions.st_x(i.geom::extensions.geometry),
         i.note, i.status, i.created_at,
         coalesce((select array_agg(r.user_id) from public.incident_responders r
                   where r.incident_id = i.id), '{}')
  from public.incidents i
  where i.id = p_id and public.is_participant(i.id)
$$;

-- Raise an SOS. Limited to 3 per hour per user so it cannot be used to spam.
create function public.create_incident(p_lat double precision, p_lon double precision, p_name text, p_note text)
  returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'not signed in'; end if;
  if p_lat not between -90 and 90 or p_lon not between -180 and 180 then
    raise exception 'bad position';
  end if;
  if (select count(*) from public.incidents
      where victim_id = (select auth.uid()) and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'too many SOS alerts, try again later';
  end if;
  insert into public.incidents (victim_id, victim_name, geom, note)
  values ((select auth.uid()), left(trim(p_name), 40),
          extensions.st_setsrid(extensions.st_makepoint(p_lon, p_lat), 4326)::extensions.geography,
          left(coalesce(p_note, ''), 280))
  returning id into v_id;
  return v_id;
end $$;

-- "I can help": only for an open SOS within 5 km of your last position.
create function public.respond_to_incident(p_incident uuid)
  returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'not signed in'; end if;
  if not public.in_range_of_open(p_incident) then
    raise exception 'incident not available';
  end if;
  insert into public.incident_responders (incident_id, user_id)
  values (p_incident, (select auth.uid()))
  on conflict do nothing;
end $$;

create function public.resolve_incident(p_incident uuid)
  returns void language sql security definer set search_path = '' as $$
  update public.incidents
     set status = 'resolved', resolved_at = now()
   where id = p_incident and victim_id = (select auth.uid()) and status = 'open'
$$;

create function public.report_user(p_user uuid, p_incident uuid, p_reason text)
  returns void language sql security definer set search_path = '' as $$
  insert into public.reports (reporter_id, reported_id, incident_id, reason)
  values ((select auth.uid()), p_user, p_incident, left(p_reason, 500))
$$;

-- Housekeeping: call on a schedule (pg_cron or the host's scheduler).
create function public.cleanup() returns void
  language sql security definer set search_path = '' as $$
  delete from public.presence where updated_at < now() - interval '2 hours';
  delete from public.incidents where created_at < now() - interval '30 days';
$$;

-- --------------------------------------------------------------- grants
-- Lock everything down, then open exactly what the app needs.

revoke all on all tables    in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant select on public.incidents, public.incident_responders, public.messages to authenticated;
grant insert on public.messages, public.reports to authenticated;

grant execute on function
  public.set_presence(double precision, double precision, text),
  public.clear_presence(),
  public.nearby_hikers(double precision, double precision, double precision),
  public.nearby_incidents(double precision, double precision, double precision),
  public.my_incident(uuid),
  public.create_incident(double precision, double precision, text, text),
  public.respond_to_incident(uuid),
  public.resolve_incident(uuid),
  public.report_user(uuid, uuid, text),
  public.is_participant(uuid),
  public.in_range_of_open(uuid)
to authenticated;
-- cleanup() and presence_ttl() are not granted: service role / cron only.

-- Realtime: stream incident and message changes (RLS still applies).
alter publication supabase_realtime add table public.incidents, public.messages, public.incident_responders;
