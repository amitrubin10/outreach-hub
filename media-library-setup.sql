-- ============================================================
-- outreach-hub — מאגר מדיה (תמונות + סרטונים) + בחירת תמונה ע"י הסוכן
-- ============================================================
-- להריץ פעם אחת ב-Supabase SQL Editor (אותו פרויקט).
-- ⚠️ החלף את שני המופעים של PUT-YOUR-OWN-SECRET-TOKEN-HERE
--    בטוקן הסודי *הזהה* שכבר הגדרת בקובץ pending-posts-setup.sql.
-- ============================================================

-- ---- 1) דלי אחסון ציבורי לקבצים ----
insert into storage.buckets (id, name, public)
values ('media','media',true)
on conflict (id) do update set public = true;

-- הרשאות כתיבה/מחיקה: רק לקבצים בתיקייה ע"ש המשתמש (uid). קריאה — ציבורית (דלי public).
drop policy if exists media_owner_insert on storage.objects;
drop policy if exists media_owner_update on storage.objects;
drop policy if exists media_owner_delete on storage.objects;
create policy media_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id='media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy media_owner_update on storage.objects for update to authenticated
  using (bucket_id='media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy media_owner_delete on storage.objects for delete to authenticated
  using (bucket_id='media' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---- 2) טבלת מטא-דאטה (שם/תגית/תיאור + קישור) ----
create table if not exists public.media_assets (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  kind        text not null,           -- image | video
  path        text not null,           -- נתיב בדלי האחסון
  url         text not null,           -- קישור ציבורי
  name        text,
  tag         text,                    -- תגית קצרה לבחירת הסוכן (למשל "חיבור בנק")
  description text
);
alter table public.media_assets enable row level security;
drop policy if exists media_assets_own on public.media_assets;
create policy media_assets_own on public.media_assets
  for all using (auth.uid()=owner) with check (auth.uid()=owner);

-- ---- 3) רשימת תמונות לסוכן (לפי תגית) — RPC מאובטח בטוקן ----
create or replace function public.list_media(p_secret text)
returns table (kind text, name text, tag text, description text, url text)
language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  if p_secret is distinct from 'PUT-YOUR-OWN-SECRET-TOKEN-HERE' then
    raise exception 'unauthorized';
  end if;
  select id into v_owner from auth.users where lower(email)=lower('amitrubin60@gmail.com') limit 1;
  return query
    select m.kind, m.name, m.tag, m.description, m.url
    from public.media_assets m
    where m.owner = v_owner and m.kind='image'
    order by m.created_at desc;
end $$;
grant execute on function public.list_media(text) to anon, authenticated;

-- ---- 4) הרחבת תיבת הנכנס: קישור תמונה שהסוכן בחר ----
alter table public.pending_posts add column if not exists image_url text;

-- מעדכנים את ingest_pending_post שיקבל גם image_url (דורס את הגרסה הישנה)
drop function if exists public.ingest_pending_post(text,text,text,text,text);
create or replace function public.ingest_pending_post(
  p_secret     text,
  p_body       text,
  p_title      text default null,
  p_image_hint text default null,
  p_angle      text default null,
  p_image_url  text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_id uuid;
begin
  if p_secret is distinct from 'PUT-YOUR-OWN-SECRET-TOKEN-HERE' then
    raise exception 'unauthorized';
  end if;
  if nullif(trim(p_body),'') is null then raise exception 'body required'; end if;
  select id into v_owner from auth.users where lower(email)=lower('amitrubin60@gmail.com') limit 1;
  if v_owner is null then raise exception 'owner not found'; end if;

  insert into public.pending_posts(owner, title, body, image_hint, angle, image_url)
  values (v_owner, nullif(trim(p_title),''), p_body,
          nullif(trim(p_image_hint),''), nullif(trim(p_angle),''), nullif(trim(p_image_url),''))
  returning id into v_id;
  return v_id;
end $$;
grant execute on function public.ingest_pending_post(text,text,text,text,text,text) to anon, authenticated;

do $$ begin raise notice '✅ media_assets + storage + list_media + image_url מוכנים'; end $$;
