-- Minimal shims mimicking what Supabase provides, so the migrations can run on
-- a bare Postgres. NOT part of the app; test harness only.
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);
-- auth.uid() reads a session GUC so tests can impersonate a user.
create or replace function auth.uid() returns uuid
  language sql stable as $$ select nullif(current_setting('app.uid', true), '')::uuid $$;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key, name text, public boolean default false, created_at timestamptz default now()
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text, owner uuid, created_at timestamptz default now()
);
alter table storage.objects enable row level security;
