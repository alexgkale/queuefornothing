-- QueueForNothing.com - Supabase setup. Paste into SQL Editor and Run. Idempotent.

create table if not exists joins (
    id bigint generated always as identity primary key,
    country text not null default 'XX',
    ts timestamptz not null default now()
  );

create table if not exists meta (
    id int primary key check (id = 1),
    served bigint not null default 0
  );
insert into meta (id, served) values (1, 0) on conflict do nothing;

alter table joins enable row level security;
alter table meta enable row level security;

create or replace function qfn_state(p_ticket bigint default 0)
returns jsonb
language sql
security definer
set search_path = public
as $func$
  select jsonb_build_object(
      'total', (select coalesce(max(id), 0) from joins),
      'served', (select served from meta where id = 1),
      'serveMs', 60000,
      'now', (extract(epoch from now()) * 1000)::bigint,
      'recent', (
        select coalesce(
          jsonb_agg(jsonb_build_object(
            'c', r.country,
            't', (extract(epoch from r.ts) * 1000)::bigint
          ) order by r.id desc),
          '[]'::jsonb
        )
        from (select id, country, ts from joins order by id desc limit 12) r
      ),
      'position', case when p_ticket > 0
        then greatest(0, p_ticket - (select served from meta where id = 1))
        else null end,
      'behind', case when p_ticket > 0
        then greatest(0, (select coalesce(max(id), 0) from joins) - p_ticket)
        else 0 end
    );
$func$;

create or replace function qfn_join(p_country text default 'XX')
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_ticket bigint;
begin
  insert into joins (country)
  values (coalesce(nullif(upper(trim(p_country)), ''), 'XX'))
  returning id into v_ticket;

  return qfn_state(v_ticket) || jsonb_build_object(
        'ticket', v_ticket,
        'joinedAt', (extract(epoch from now()) * 1000)::bigint
      );
end;
$func$;

create extension if not exists pg_cron;

do $do$
begin
  perform cron.unschedule('qfn-advance');
exception when others then
  null;
end $do$;

select cron.schedule(
    'qfn-advance',
    '* * * * *',
    $job$ update meta
       set served = least((select coalesce(max(id), 0) from joins), served + 1)
       where id = 1 $job$
  );
