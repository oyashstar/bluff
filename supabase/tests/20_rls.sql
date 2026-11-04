\set ON_ERROR_STOP on
-- Recreate the Supabase-style roles and grant table privileges (Supabase does
-- this; the migrations assume 'authenticated' exists). RLS then decides writes.
do $$ begin
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Make two users with known roles.
do $$
declare uview uuid; ucons uuid;
begin
  insert into auth.users(email, raw_user_meta_data) values('view@finsys.test','{"name":"Vic Viewer"}') returning id into uview;
  insert into auth.users(email, raw_user_meta_data) values('cons2@finsys.test','{"name":"Cleo Consultant"}') returning id into ucons;
  update app_user set role='Viewer' where id=uview;
  update app_user set role='Consultant' where id=ucons;
  perform set_config('test.uview', uview::text, false);
  perform set_config('test.ucons', ucons::text, false);
end $$;

\gset
select current_setting('test.uview') as uview, current_setting('test.ucons') as ucons \gset

-- ===== As a VIEWER: can read, cannot write =====
set role authenticated;
select set_config('app.uid', :'uview', false);

-- read allowed
do $$ begin
  perform 1 from client limit 1;
  raise notice 'VIEWER read client: OK';
end $$;

-- insert must be blocked by RLS
do $$
declare blocked boolean := false;
begin
  begin
    insert into client(code,name) values('HACK01','Should Fail');
  exception when insufficient_privilege or others then blocked := true;
  end;
  assert blocked, 'RLS FAILED: viewer was able to insert a client';
  raise notice 'VIEWER insert client: correctly BLOCKED';
end $$;

-- viewer cannot escalate own role
do $$
declare blocked boolean := false; uid uuid := current_setting('app.uid')::uuid;
begin
  begin
    update app_user set role='Admin' where id = uid;
    -- if it ran, verify it did not actually change (check constraint via policy)
    if (select role from app_user where id=uid) = 'Admin' then blocked := false; else blocked := true; end if;
  exception when others then blocked := true;
  end;
  assert blocked, 'RLS FAILED: viewer escalated own role to Admin';
  raise notice 'VIEWER self role-escalation: correctly BLOCKED';
end $$;

reset role;

-- ===== As a CONSULTANT: can write delivery data =====
set role authenticated;
select set_config('app.uid', :'ucons', false);

do $$
declare cid uuid; ok boolean := false;
begin
  insert into client(code,name,segment) values('CONS01','Consultant Co','Packaging') returning id into cid;
  ok := cid is not null;
  assert ok, 'consultant could not insert client';
  raise notice 'CONSULTANT insert client: OK (%).', cid;
end $$;

-- consultant cannot write support-only? (they can: canEditSupport includes consultant) -> instead test anon
reset role;

-- ===== As ANON (no app_user row): sees nothing =====
set role anon;
-- anon has no table grants -> even select should fail at privilege level
do $$
declare blocked boolean := false;
begin
  begin
    perform 1 from client limit 1;
  exception when insufficient_privilege or others then blocked := true;
  end;
  assert blocked, 'anon unexpectedly could read client';
  raise notice 'ANON read: correctly BLOCKED (no grant)';
end $$;
reset role;

select 'ALL RLS TESTS PASSED' as result;
