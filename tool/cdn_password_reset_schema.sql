-- Password reset tokens for CDN auth service.
-- Important:
-- 1. Keep this table out of public/Hasura roles.
-- 2. Access it only from the server-side auth service.
-- 3. Tokens must be stored hashed, never plaintext.

create table if not exists public.password_reset_tokens (
  id bigserial primary key,
  user_id bigint not null references public.users(id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  requested_ip text,
  user_agent text
);

create index if not exists password_reset_tokens_user_active_idx
  on public.password_reset_tokens (user_id, expires_at desc)
  where used_at is null;

create index if not exists password_reset_tokens_expires_idx
  on public.password_reset_tokens (expires_at);

comment on table public.password_reset_tokens is
  'Single-use password reset tokens. Store only SHA-256 hashes here.';
