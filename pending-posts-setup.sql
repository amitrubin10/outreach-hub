-- ============================================================
-- outreach-hub — תיבת נכנס לפוסטים מהסוכן (pending_posts)
-- ============================================================
-- להריץ פעם אחת ב-Supabase SQL Editor (אותו פרויקט VeriBayit).
-- - טבלה שמחזיקה פוסטים שהסוכן שלח, במצב 'pending' (טרם פורסם).
-- - RLS: רק הבעלים (amitrubin60@gmail.com, מחובר) רואה/מעדכן/מוחק.
-- - הכנסה (insert) אפשרית רק דרך ה-RPC המאובטח עם טוקן סודי —
--   כך המשימה המתוזמנת ב-Cowork יכולה לכתוב בלי התחברות, בלי לחשוף מפתח רגיש.
--
-- ⚠️ חובה: החלף את PUT-YOUR-OWN-SECRET-TOKEN-HERE למטה במחרוזת אקראית
--    ארוכה משלך (למשל 30+ תווים). זהו "מפתח הכתיבה" לתיבת הנכנס.
--    שמור אותו בסוד! אל תעלה אותו לגיט. אותו טוקן בדיוק תשים במשימה ב-Cowork.
--    (הקובץ הזה ב-repo ציבורי — לכן הוא מכיל placeholder בלבד, לא טוקן אמיתי.)
-- ============================================================

create table if not exists public.pending_posts (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  title      text,
  body       text not null,
  image_hint text,          -- "תמונה מומלצת" שהסוכן ממליץ
  angle      text,          -- זווית הפוסט (כאב/יתרון/טיפ...)
  status     text not null default 'pending',  -- pending | published
  source     text default 'agent'
);

alter table public.pending_posts enable row level security;

drop policy if exists pending_own_select on public.pending_posts;
drop policy if exists pending_own_update on public.pending_posts;
drop policy if exists pending_own_delete on public.pending_posts;

create policy pending_own_select on public.pending_posts
  for select using (auth.uid() = owner);
create policy pending_own_update on public.pending_posts
  for update using (auth.uid() = owner) with check (auth.uid() = owner);
create policy pending_own_delete on public.pending_posts
  for delete using (auth.uid() = owner);
-- שים לב: אין policy ל-insert מצד הלקוח — הכנסה רק דרך ה-RPC למטה.

-- ---- RPC מאובטח: הסוכן/המשימה קוראים לזה עם הטוקן הסודי ----
create or replace function public.ingest_pending_post(
  p_secret     text,
  p_body       text,
  p_title      text default null,
  p_image_hint text default null,
  p_angle      text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_id uuid;
begin
  if p_secret is distinct from 'PUT-YOUR-OWN-SECRET-TOKEN-HERE' then
    raise exception 'unauthorized';
  end if;
  if nullif(trim(p_body),'') is null then
    raise exception 'body required';
  end if;
  select id into v_owner from auth.users
   where lower(email) = lower('amitrubin60@gmail.com') limit 1;
  if v_owner is null then raise exception 'owner not found'; end if;

  insert into public.pending_posts(owner, title, body, image_hint, angle)
  values (v_owner, nullif(trim(p_title),''), p_body,
          nullif(trim(p_image_hint),''), nullif(trim(p_angle),''))
  returning id into v_id;
  return v_id;
end $$;

grant execute on function public.ingest_pending_post(text,text,text,text,text) to anon, authenticated;

do $$ begin raise notice '✅ pending_posts + ingest_pending_post מוכנים'; end $$;
