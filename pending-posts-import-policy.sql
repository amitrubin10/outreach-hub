-- ============================================================
-- ייבוא פוסט ידני — מאפשר למשתמש המחובר (הבעלים) להכניס פוסט
-- ישירות לתיבת הנכנס, בלי ה-RPC/טוקן (כי הסוכן מדביק ידנית).
-- להריץ פעם אחת ב-Supabase SQL Editor.
-- ============================================================
drop policy if exists pending_own_insert on public.pending_posts;
create policy pending_own_insert on public.pending_posts
  for insert with check (auth.uid() = owner);

do $$ begin raise notice '✅ pending_own_insert מוכן — אפשר לייבא פוסט ידנית'; end $$;
