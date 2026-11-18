-- Tearly database. Run this once in the Supabase SQL editor.
-- Every table has row-level security: the rules below, not the app, decide who can read what.

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null default '' check (char_length(display_name) <= 40),
  created_at timestamptz not null default now()
);

create table public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  at timestamptz not null default now(),
  level smallint not null check (level between 1 and 5),
  reasons text[] not null default '{}',
  cope text[] not null default '{}',
  note text not null default '' check (char_length(note) <= 4000),
  "after" text not null default '' check ("after" in ('', 'lighter', 'same', 'heavier')),
  created_at timestamptz not null default now()
);
create index entries_user_at on public.entries (user_id, at desc);

create table public.friendships (
  requester uuid not null references public.profiles on delete cascade,
  addressee uuid not null references public.profiles on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (requester, addressee),
  check (requester <> addressee)
);
-- one friendship per pair, whichever of the two asked first
create unique index friendships_pair on public.friendships (least(requester, addressee), greatest(requester, addressee));

-- a cry someone chose to tell their friends about: only when and how hard, never why
create table public.shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  at timestamptz not null default now(),
  level smallint not null check (level between 1 and 5),
  created_at timestamptz not null default now()
);

create table public.hugs (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null default auth.uid() references public.profiles on delete cascade,
  to_id uuid not null references public.profiles on delete cascade,
  share_id uuid not null references public.shares on delete cascade,
  created_at timestamptz not null default now(),
  unique (from_id, share_id)
);

create function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  -- only ever answers for the person asking, so it cannot be used to look up other people's friendships
  select auth.uid() in (a, b) and exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.entries enable row level security;
alter table public.friendships enable row level security;
alter table public.shares enable row level security;
alter table public.hugs enable row level security;

-- profiles: any signed-in person can look up a username; you can only write your own
create policy "read profiles" on public.profiles for select to authenticated using (true);
create policy "create own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "edit own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- entries: yours alone
create policy "own entries" on public.entries for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- friendships: visible to the two people in them; only the person asked can accept
create policy "see own friendships" on public.friendships for select to authenticated using (auth.uid() in (requester, addressee));
create policy "ask" on public.friendships for insert to authenticated with check (requester = auth.uid() and status = 'pending');
create policy "accept" on public.friendships for update to authenticated using (addressee = auth.uid()) with check (addressee = auth.uid() and status = 'accepted');
create policy "leave" on public.friendships for delete to authenticated using (auth.uid() in (requester, addressee));
revoke update on public.friendships from authenticated;
grant update (status, accepted_at) on public.friendships to authenticated;

-- shared cries: readable by you and your accepted friends only
create policy "see friends' shares" on public.shares for select to authenticated using (user_id = auth.uid() or public.are_friends(user_id, auth.uid()));
create policy "share own" on public.shares for insert to authenticated with check (user_id = auth.uid());
create policy "unshare own" on public.shares for delete to authenticated using (user_id = auth.uid());

-- hugs: only between friends, only for a cry that friend actually shared
create policy "see own hugs" on public.hugs for select to authenticated using (auth.uid() in (from_id, to_id));
create policy "send hug" on public.hugs for insert to authenticated with check (
  from_id = auth.uid()
  and public.are_friends(from_id, to_id)
  and exists (select 1 from public.shares s where s.id = share_id and s.user_id = to_id)
);

-- fuller reflections written by the "reflect" function: kept so they can be rate-limited per person
create table public.reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  text text not null,
  entry_count int not null default 0,
  created_at timestamptz not null default now()
);
create index reflections_user_at on public.reflections (user_id, created_at desc);
alter table public.reflections enable row level security;
create policy "own reflections" on public.reflections for select to authenticated using (user_id = auth.uid());
create policy "record own reflection" on public.reflections for insert to authenticated with check (user_id = auth.uid());

-- live updates for the Friends tab
alter publication supabase_realtime add table public.friendships, public.shares, public.hugs;
