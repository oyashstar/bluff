-- Finsys Internal Tracker — RLS helper functions
-- Small, stable predicates the policies read. SECURITY DEFINER so a policy can
-- consult app_user without the caller needing a policy on app_user that would
-- recurse. search_path pinned.

-- The caller's role, or null if they are not an active internal user.
create or replace function fn_my_role() returns app_role
  language sql
  stable
  security definer
  set search_path = public, auth
as $$
  select role from app_user where id = auth.uid() and is_active = true;
$$;

-- True when the caller's role is one of the supplied roles.
create or replace function fn_has_role(variadic roles app_role[]) returns boolean
  language sql
  stable
  security definer
  set search_path = public, auth
as $$
  select fn_my_role() = any(roles);
$$;

-- True for any active internal user (everyone who should see the app at all).
create or replace function fn_is_internal() returns boolean
  language sql
  stable
  security definer
  set search_path = public, auth
as $$
  select fn_my_role() is not null;
$$;

-- Editors of operational data: Admin, Manager, Consultant.
create or replace function fn_can_edit_delivery() returns boolean
  language sql
  stable
  security definer
  set search_path = public, auth
as $$
  select fn_my_role() in ('Admin','Manager','Consultant');
$$;

-- Editors of support data: Admin, Manager, Consultant, Support.
create or replace function fn_can_edit_support() returns boolean
  language sql
  stable
  security definer
  set search_path = public, auth
as $$
  select fn_my_role() in ('Admin','Manager','Consultant','Support');
$$;
