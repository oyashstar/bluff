-- Finsys Internal Tracker — audit log
-- One generic trigger function, attached to every operational table. Writing it
-- in the database (not Dart) means anything that changes a row is captured,
-- including changes made outside the app. The actor is auth.uid() at write time.

create or replace function fn_audit() returns trigger
  language plpgsql
  security definer
  set search_path = public, auth
as $$
declare
  v_entity_id text;
  v_before jsonb;
  v_after  jsonb;
begin
  if (tg_op = 'DELETE') then
    v_before := to_jsonb(old);
    v_after  := null;
    v_entity_id := coalesce((old).id::text, '');
  elsif (tg_op = 'UPDATE') then
    v_before := to_jsonb(old);
    v_after  := to_jsonb(new);
    v_entity_id := coalesce((new).id::text, '');
    -- Skip no-op updates (row written but nothing actually changed).
    if v_before = v_after then
      return new;
    end if;
  else -- INSERT
    v_before := null;
    v_after  := to_jsonb(new);
    v_entity_id := coalesce((new).id::text, '');
  end if;

  insert into audit_log (entity_type, entity_id, action, changed_by, before_json, after_json)
  values (tg_table_name, v_entity_id, tg_op, auth.uid(), v_before, v_after);

  if (tg_op = 'DELETE') then
    return old;
  end if;
  return new;
end;
$$;

-- Attach to every table that carries a uuid/text id and is worth auditing.
-- audit_log itself is excluded (it is append-only and never updated).
do $$
declare
  t text;
  audited text[] := array[
    'app_user', 'client', 'client_contact', 'module_master',
    'stage_template', 'stage_template_item',
    'project', 'project_module', 'project_stage', 'signoff', 'touchpoint',
    'query', 'query_comment', 'attachment', 'client_financial_snapshot'
  ];
begin
  foreach t in array audited loop
    execute format(
      'create trigger trg_audit_%1$s
         after insert or update or delete on %1$I
         for each row execute function fn_audit()', t);
  end loop;
end;
$$;
