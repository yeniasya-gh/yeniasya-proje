create table if not exists public.faq (
  id serial primary key,
  title text not null,
  description text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_faq_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists faq_set_updated_at on public.faq;

create trigger faq_set_updated_at
before update on public.faq
for each row
execute function public.set_faq_updated_at();

create index if not exists faq_active_sort_idx
  on public.faq (is_active, sort_order, id);
