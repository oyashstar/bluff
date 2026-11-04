-- Finsys Internal Tracker — business-hours calendar + SLA targets
-- Working week: Mon–Sat, 09:30–18:30 IST (Asia/Kolkata). Sundays off, plus a
-- holiday table. SLA breach is measured against business minutes net of paused
-- time. Everything is stored timestamptz; all clock maths happens in IST.

-- Editable holiday list. Half-days (e.g. a festival eve) can be modelled later;
-- v1 treats a holiday as a full non-working day.
create table holiday (
  holiday_date date primary key,
  name         text not null,
  created_at   timestamptz not null default now()
);
alter table holiday enable row level security;
create policy holiday_read on holiday
  for select using (fn_is_internal());
create policy holiday_write on holiday
  for all using (fn_has_role('Admin','Manager')) with check (fn_has_role('Admin','Manager'));

-- SLA targets per severity, in business minutes. Editable data (same philosophy
-- as stage_template). first_response = time to Acknowledge;
-- resolution = time to Resolved. Seeded in seed.sql.
create table sla_target (
  severity               query_severity primary key,
  first_response_minutes int not null,
  resolution_minutes     int not null
);
alter table sla_target enable row level security;
create policy sla_target_read on sla_target
  for select using (fn_is_internal());
create policy sla_target_write on sla_target
  for all using (fn_has_role('Admin','Manager')) with check (fn_has_role('Admin','Manager'));

-- Is a given IST calendar date a working day? (Not Sunday, not a holiday.)
create or replace function fn_is_working_day(p_date date) returns boolean
  language sql
  stable
as $$
  select extract(dow from p_date) <> 0        -- 0 = Sunday
     and not exists (select 1 from holiday h where h.holiday_date = p_date);
$$;

-- Business minutes between two instants, Mon–Sat 09:30–18:30 IST, net of
-- holidays. Returns 0 if p_to <= p_from. Walks day by day; fine for SLA ranges
-- which are days-to-weeks on small data.
create or replace function fn_business_minutes_between(p_from timestamptz, p_to timestamptz)
  returns int
  language plpgsql
  stable
as $$
declare
  f timestamp;          -- local IST wall-clock
  t timestamp;
  d date;
  win_open  timestamp;
  win_close timestamp;
  seg_start timestamp;
  seg_end   timestamp;
  total int := 0;
begin
  if p_to is null or p_from is null or p_to <= p_from then
    return 0;
  end if;
  f := (p_from at time zone 'Asia/Kolkata');
  t := (p_to   at time zone 'Asia/Kolkata');

  d := f::date;
  while d <= t::date loop
    if fn_is_working_day(d) then
      win_open  := d + time '09:30';
      win_close := d + time '18:30';
      seg_start := greatest(win_open, f);
      seg_end   := least(win_close, t);
      if seg_end > seg_start then
        total := total + floor(extract(epoch from (seg_end - seg_start)) / 60)::int;
      end if;
    end if;
    d := d + 1;
  end loop;
  return total;
end;
$$;

-- Add N business minutes to an instant, returning the deadline as timestamptz.
-- Used to compute sla_response_due / sla_resolution_due at ticket creation.
create or replace function fn_add_business_minutes(p_from timestamptz, p_minutes int)
  returns timestamptz
  language plpgsql
  stable
as $$
declare
  cur timestamp;        -- local IST wall-clock; starting point within the current day
  d date;
  win_open  timestamp;
  win_close timestamp;
  start_pt  timestamp;
  avail int;
  remaining int := greatest(p_minutes, 0);
  guard int := 0;       -- loop guard: at most ~10 years of days
begin
  if p_from is null then
    return null;
  end if;
  cur := (p_from at time zone 'Asia/Kolkata');
  d := cur::date;

  loop
    if fn_is_working_day(d) then
      win_open  := d + time '09:30';
      win_close := d + time '18:30';
      -- First day starts from max(now, window open); later days from window open
      -- (cur is reset to midnight below, and greatest() clamps it to 09:30).
      start_pt := greatest(win_open, cur);
      if start_pt < win_close then
        avail := floor(extract(epoch from (win_close - start_pt)) / 60)::int;
        if remaining <= avail then
          return (start_pt + make_interval(mins => remaining)) at time zone 'Asia/Kolkata';
        end if;
        remaining := remaining - avail;
      end if;
    end if;
    d := d + 1;
    cur := d + time '00:00';
    guard := guard + 1;
    if guard > 3650 then
      return null;             -- safety valve; should never trigger
    end if;
  end loop;
end;
$$;
