create table public.cert_progress (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  cert_id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, cert_id)
);

alter table public.cert_progress enable row level security;
revoke all on table public.cert_progress from anon, authenticated;
grant select, insert, update on table public.cert_progress to authenticated;

create policy "Users read their own progress" on public.cert_progress for select
to authenticated
using ( (select auth.uid()) = user_id );

create policy "Users create their own progress" on public.cert_progress for insert
to authenticated
with check ( (select auth.uid()) = user_id );

create policy "Users update their own progress" on public.cert_progress for update
to authenticated
using ( (select auth.uid()) = user_id )
with check ( (select auth.uid()) = user_id );
