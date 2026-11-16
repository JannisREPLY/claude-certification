drop policy "Users read their own progress" on public.cert_progress;
drop policy "Users create their own progress" on public.cert_progress;
drop policy "Users update their own progress" on public.cert_progress;

create policy "Owner reads progress" on public.cert_progress for select
to authenticated
using ( (select auth.uid()) = user_id and user_id = '0941a759-2f45-4970-a66c-e78658331aa4' );

create policy "Owner creates progress" on public.cert_progress for insert
to authenticated
with check ( (select auth.uid()) = user_id and user_id = '0941a759-2f45-4970-a66c-e78658331aa4' );

create policy "Owner updates progress" on public.cert_progress for update
to authenticated
using ( (select auth.uid()) = user_id and user_id = '0941a759-2f45-4970-a66c-e78658331aa4' )
with check ( (select auth.uid()) = user_id and user_id = '0941a759-2f45-4970-a66c-e78658331aa4' );
