-- ============================================================
-- outreach-hub — סנכרון ענן (Supabase)
-- ============================================================
-- להריץ פעם אחת ב-Supabase SQL Editor של פרויקט VeriBayit.
-- יוצר טבלה אחת ששומרת את כל מצב הכלי כ-JSONB, מבודדת ב-RLS:
-- כל משתמש (מחובר) רואה וכותב רק את השורה שלו. אף אחד אחר לא.
-- ============================================================

create table if not exists public.outreach_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.outreach_state enable row level security;

drop policy if exists outreach_own_select on public.outreach_state;
drop policy if exists outreach_own_insert on public.outreach_state;
drop policy if exists outreach_own_update on public.outreach_state;

create policy outreach_own_select on public.outreach_state
  for select using (auth.uid() = user_id);

create policy outreach_own_insert on public.outreach_state
  for insert with check (auth.uid() = user_id);

create policy outreach_own_update on public.outreach_state
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
