-- =========================================================
-- Halaqati cloud schema. Run once in the Supabase SQL Editor.
-- One teacher account = one halaqa. Every row carries teacher_id
-- and is reachable only through its own RLS policy.
-- =========================================================

-- ---------- teacher (one row per auth user) ----------
create table public.teacher (
  id             uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  name           text not null,
  madrassa_name  text not null default '',
  halaqa_name    text not null default '',
  phone          text,
  created_at     timestamptz not null default now()
);

-- ---------- settings (one row per teacher) ----------
-- theme_mode replaces the local-only appearance preference; there is no
-- language column because the app is Arabic-only.
create table public.settings (
  teacher_id    uuid primary key references public.teacher(id) on delete cascade,
  hodor_weight  double precision not null default 0.4 check (hodor_weight between 0 and 1),
  hifd_weight   double precision not null default 0.6 check (hifd_weight between 0 and 1),
  theme_mode    text not null default 'system' check (theme_mode in ('system','light','dark'))
);

-- ---------- student (soft delete via active) ----------
create table public.student (
  id               uuid primary key default gen_random_uuid(),
  teacher_id       uuid not null default auth.uid() references public.teacher(id) on delete cascade,
  full_name        text not null,
  birth_date       date,
  guardian_phone   text,
  enrollment_date  date,
  active           boolean not null default true,
  notes            text,
  created_at       timestamptz not null default now(),
  unique (id, teacher_id)
);

-- ---------- attendance (one per student per day) ----------
create table public.attendance (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid not null default auth.uid(),
  student_id  uuid not null,
  date        date not null,
  status      text not null check (status in ('present','absent','late','excused')),
  unique (student_id, date),
  foreign key (student_id, teacher_id)
    references public.student(id, teacher_id) on delete cascade
);

-- ---------- hifd_entry (jadid / muraja3a, one per student+date+type) ----------
create table public.hifd_entry (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid not null default auth.uid(),
  student_id  uuid not null,
  date        date not null,
  type        text not null check (type in ('jadid','muraja3a')),
  surah_from  int not null check (surah_from between 1 and 114),
  ayah_from   int not null check (ayah_from >= 1),
  surah_to    int not null check (surah_to between 1 and 114),
  ayah_to     int not null check (ayah_to >= 1),
  grade       smallint not null check (grade in (1,2,3)),
  unique (student_id, date, type),
  foreign key (student_id, teacher_id)
    references public.student(id, teacher_id) on delete cascade
);

-- ---------- hifd_day_lock (a confirmed day is frozen) ----------
create table public.hifd_day_lock (
  teacher_id  uuid not null default auth.uid() references public.teacher(id) on delete cascade,
  date        date not null,
  locked_at   timestamptz not null default now(),
  primary key (teacher_id, date)
);

-- ---------- indexes ----------
create index on public.student       (teacher_id, active);
create index on public.attendance    (teacher_id, date);
create index on public.hifd_entry    (teacher_id, date);
create index on public.hifd_entry    (student_id);
create index on public.hifd_day_lock (teacher_id, date);

-- ---------- default settings row when a teacher is created ----------
create or replace function public.create_default_settings() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.settings (teacher_id) values (new.id);
  return new;
end $$;

create trigger trg_teacher_default_settings after insert on public.teacher
  for each row execute function public.create_default_settings();

-- ---------- Row Level Security ----------
alter table public.teacher       enable row level security;
alter table public.settings      enable row level security;
alter table public.student       enable row level security;
alter table public.attendance    enable row level security;
alter table public.hifd_entry    enable row level security;
alter table public.hifd_day_lock enable row level security;

create policy teacher_own on public.teacher for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy settings_own on public.settings for all to authenticated
  using (teacher_id = (select auth.uid())) with check (teacher_id = (select auth.uid()));

create policy student_own on public.student for all to authenticated
  using (teacher_id = (select auth.uid())) with check (teacher_id = (select auth.uid()));

create policy attendance_own on public.attendance for all to authenticated
  using (teacher_id = (select auth.uid())) with check (teacher_id = (select auth.uid()));

create policy hifd_own on public.hifd_entry for all to authenticated
  using (teacher_id = (select auth.uid())) with check (teacher_id = (select auth.uid()));

create policy hifd_lock_own on public.hifd_day_lock for all to authenticated
  using (teacher_id = (select auth.uid())) with check (teacher_id = (select auth.uid()));

-- ---------- Realtime ----------
alter table public.student       replica identity full;
alter table public.attendance    replica identity full;
alter table public.hifd_entry    replica identity full;
alter table public.settings      replica identity full;
alter table public.hifd_day_lock replica identity full;

alter publication supabase_realtime add table
  public.student, public.attendance, public.hifd_entry, public.settings,
  public.hifd_day_lock;