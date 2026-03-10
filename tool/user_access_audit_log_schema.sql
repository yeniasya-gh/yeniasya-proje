create table if not exists public.user_access_audit_log (
  id bigserial primary key,
  user_id bigint not null references public.users(id) on delete cascade,
  actor_user_id bigint references public.users(id) on delete set null,
  action text not null,
  item_type public.access_item_type not null,
  item_id integer,
  item_title text,
  access_source text,
  previous_expires_at timestamptz,
  new_expires_at timestamptz,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists user_access_audit_log_user_created_idx
  on public.user_access_audit_log (user_id, created_at desc);

create index if not exists user_access_audit_log_actor_created_idx
  on public.user_access_audit_log (actor_user_id, created_at desc);
