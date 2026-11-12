-- Gietgenoten: wachtlijst voor de aankondigingspagina
-- Voer dit uit in Supabase bij SQL Editor. Het script mag je vaker uitvoeren.
-- Bekijken: Table Editor, tabel waitlist. Alleen jij ziet de aanmeldingen in het dashboard.

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null check (char_length(email) <= 200 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  suggestie text check (suggestie is null or char_length(suggestie) <= 1000),
  created_at timestamptz not null default now()
);
create unique index if not exists waitlist_email on public.waitlist (lower(email));
alter table public.waitlist enable row level security;

-- Iedereen mag zich aanmelden, niemand kan de lijst via de website lezen of wijzigen.
drop policy if exists waitlist_add on public.waitlist;
create policy waitlist_add on public.waitlist for insert to anon, authenticated with check (true);
grant insert on public.waitlist to anon, authenticated;
revoke select, update, delete on public.waitlist from anon, authenticated;

-- Rem tegen spam: maximaal 20 aanmeldingen per 10 minuten voor de hele site.
create or replace function public.waitlist_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from waitlist where created_at > now() - interval '10 minutes') >= 20 then
    raise exception 'te_druk';
  end if;
  new.email := lower(trim(new.email));
  new.suggestie := nullif(trim(coalesce(new.suggestie, '')), '');
  new.created_at := now();
  return new;
end $$;
drop trigger if exists waitlist_rate on public.waitlist;
create trigger waitlist_rate before insert on public.waitlist for each row execute function public.waitlist_rate_limit();
