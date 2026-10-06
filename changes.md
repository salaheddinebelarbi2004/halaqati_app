# changes.md: Halaqati, migrate from local SQLite to Supabase (cloud-only)

> Audience: AI coding agents. Execute the phases **in order** and verify each acceptance check before moving on.
> Base: the current Halaqati README (Flutter, sqflite, flutter_riverpod, Arabic RTL, ar/fr/en).
> Do not change features, scoring formulas, or UI design. Only the storage/auth layer changes.

---

## 0. Final decisions (do not re-decide)

| Topic | Decision |
|---|---|
| Storage | Supabase PostgreSQL. **SQLite fully removed** (`sqflite`, `halaqati.db`, `DatabaseService`) |
| Auth | Supabase Auth, email + password. New `LoginScreen` |
| Tenancy | **One teacher account = one halaqa.** Every row belongs to `teacher_id = auth.uid()` |
| Access control | Row Level Security on every table |
| Sync | Realtime on all data tables (multi-device, same account) |
| Connectivity | **Cloud-only.** No local cache, no offline queue |
| Offline message | Exactly: `لا يوجد اتصال بالإنترنت` (shown in Arabic for ALL locales) |
| Backup | `BackUpScreen`, `BackupService`, `/backup` route **deleted** |
| `surah_aya.json` | **Stays in Flutter assets** and `SurahCatalog` is untouched. Never uploaded to Supabase |
| PDF reports | `PdfService` + `printing` + `share_plus` **stay** (they are for reports, not backup) |
| Secrets | Only the `anon` key in the app, passed with `--dart-define`. Never `service_role` |

New flow:

```
Flutter UI (Riverpod) -> services -> supabase_flutter -> Supabase Auth + PostgREST (RLS) -> PostgreSQL
                                          ^----------- Realtime websocket ------------'
```

---

## 1. Phase 0: Audit (no edits yet)

Produce a scratch `AUDIT.md` (deleted at the end) listing:

1. Every method of `lib/services/database_service.dart` (signature, SQL used, who calls it).
2. Every file importing `sqflite`, `path`, `path_provider`, `file_picker`, `share_plus`, `dart:io`.
3. Every Riverpod provider that reads/writes data.
4. How `RankingService` obtains `totalDays` (distinct attendance dates in range? per student? session totals?). **Preserve the exact semantics** when re-implementing.
5. Where the "historical read-only window" is enforced in screens (keep it in the UI).
6. All usages of `int` IDs (`student.id`, routes arguments, map keys). They become `String` (UUID).
7. All places referencing backup (menu entries, home buttons, settings, l10n keys, platform permissions).

Acceptance: the audit lists all methods to port and all files to delete.

---

## 2. Phase 1: Database schema -> create `supabase/schema.sql`

Table and column names are kept the same as the SQLite ones so models change minimally. Integer IDs become UUIDs; every row gets `teacher_id`.

```sql
-- =========================================================
-- Halaqati cloud schema. Run once in Supabase SQL Editor.
-- =========================================================

-- ---------- teacher (one row per auth user) ----------
create table public.teacher (
  id             uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  name           text not null,
  madrassa_name  text,
  halaqa_name    text,
  phone          text,
  created_at     timestamptz not null default now()
);

-- ---------- settings (one row per teacher) ----------
create table public.settings (
  teacher_id    uuid primary key references public.teacher(id) on delete cascade,
  hodor_weight  double precision not null default 0.4 check (hodor_weight between 0 and 1),
  hifd_weight   double precision not null default 0.6 check (hifd_weight between 0 and 1),
  language      text not null default 'ar' check (language in ('ar','fr','en'))
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

-- ---------- indexes ----------
create index on public.student    (teacher_id, active);
create index on public.attendance (teacher_id, date);
create index on public.hifd_entry (teacher_id, date);
create index on public.hifd_entry (student_id);

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
alter table public.teacher    enable row level security;
alter table public.settings   enable row level security;
alter table public.student    enable row level security;
alter table public.attendance enable row level security;
alter table public.hifd_entry enable row level security;

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

-- ---------- Realtime ----------
alter table public.student    replica identity full;
alter table public.attendance replica identity full;
alter table public.hifd_entry replica identity full;
alter table public.settings   replica identity full;

alter publication supabase_realtime add table
  public.student, public.attendance, public.hifd_entry, public.settings;
```

Rules:
- No policy targets `anon`. No `using (true)`.
- The composite foreign keys make it impossible to attach attendance/hifd rows to another teacher's student.
- Do not create tables for `surah_aya.json`.

---

## 3. Phase 2: Dependencies and configuration

### 3.1 `pubspec.yaml`
**Add:** `supabase_flutter`, `connectivity_plus` (latest stable compatible with Flutter 3.38.3 / Dart 3.10.1).

**Remove:** `sqflite`, and `file_picker`.
**Remove only if the audit shows no remaining usage:** `path`, `path_provider`.
**Keep:** `flutter_riverpod`, `pdf`, `printing`, `share_plus` (PDF reports), `intl`, `flutter_localizations`, UI packages, and the asset entry for `surah_aya.json`.

### 3.2 Config (no secrets in git)
`lib/core/config/env.dart`:
```dart
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```
Run/build:
```
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build apk --release --target-platform android-arm64 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

### 3.3 `main.dart`
```dart
WidgetsFlutterBinding.ensureInitialized();
await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
await SurahCatalog.load(); // unchanged, if it is currently loaded at startup
runApp(const ProviderScope(child: HalaqatiApp()));
```
Remove any SQLite initialization.

Acceptance: `flutter pub get` succeeds; no sqflite import in `main.dart`.

---

## 4. Phase 3: Authentication and new startup flow

### 4.1 Files
- `lib/screens/login_screen.dart`
- `lib/services/auth_service.dart` (wraps `supabase.auth`)
- Riverpod providers in the existing providers location: `authStateProvider` (stream of `onAuthStateChange`), `currentSessionProvider`.

### 4.2 `RootScreen` new logic (replaces "teacher exists in SQLite" check)
1. No session -> `LoginScreen`.
2. Session + no row in `teacher` for this user -> `OnboardingScreen`.
3. Session + teacher row -> `HomeScreen`.

Listen to `onAuthStateChange` so login/logout navigates automatically. Session persistence is built into `supabase_flutter`; do not store tokens manually.

### 4.3 `LoginScreen`
- Arabic, RTL, same theme/fonts (google_fonts, screenutil, iconsax, gap) as existing screens.
- Fields: email, password (show/hide). Validation: valid email, password >= 6 chars.
- Buttons: **تسجيل الدخول**, **إنشاء حساب** (signUp), link **نسيت كلمة المرور؟** (`resetPasswordForEmail`).
- Loading state disables buttons.
- Error mapping (Arabic): invalid credentials -> `البريد الإلكتروني أو كلمة المرور غير صحيحة`; email not confirmed -> `يرجى تأكيد بريدك الإلكتروني أولا`; network -> `لا يوجد اتصال بالإنترنت`; other -> `حدث خطأ غير متوقع`.
- Add translations for fr/en for all labels except the offline message (always Arabic text).
- Add route `/login` to `AppRoutes`.

### 4.4 Onboarding change
`OnboardingScreen` now inserts into `teacher` (`id` defaults to `auth.uid()`). The trigger creates the default `settings` row. Nothing else changes in its UI.

### 4.5 Logout
In `SettingsScreen` add **تسجيل الخروج** calling `auth.signOut()`. Also show the account email there. After logout, invalidate all Riverpod data providers so no data from the previous account remains in memory.

Acceptance: fresh install shows Login; login -> onboarding (first time) or home; app restart keeps the session; logout returns to Login.

---

## 5. Phase 4: Replace `DatabaseService` with a Supabase service

### 5.1 Approach
- Create `lib/services/supabase_data_service.dart` exposing **the same public methods** as the old `DatabaseService` (teacher, students, attendance, hifd entries, settings, report helpers), so screens and providers need only type changes.
- Delete `lib/services/database_service.dart` afterwards.
- **Delete** `exportAllData` / `importAllData` equivalents entirely.

### 5.2 Models (`lib/models/*`)
- `id` and `student_id` become `String` (UUID). Update every comparison, route argument, map key, and widget key.
- Add `fromJson` / `toJson` aligned with the SQL column names (snake_case). Replace old `fromMap/toMap` or alias them.
- `date` columns use `yyyy-MM-dd` strings. `active` is a real `bool` (was `0/1`).
- `Settings`: `hodor_weight`, `hifd_weight` as `double`, `language` as `String`.
- Never send `teacher_id` from the client; the DB default is `auth.uid()`.

### 5.3 Operation mapping
| Old | New |
|---|---|
| insert student | `from('student').insert(json).select().single()` |
| soft delete | `from('student').update({'active': false}).eq('id', id)` |
| `saveAttendance` (upsert) | `from('attendance').upsert(json, onConflict: 'student_id,date')` |
| `saveHifdEntry` (upsert) | `from('hifd_entry').upsert(json, onConflict: 'student_id,date,type')` |
| save many attendance rows | single `upsert(list, onConflict: 'student_id,date')` call |
| settings update | `from('settings').update(json).eq('teacher_id', uid)` |
| teacher read/write | `from('teacher').select().maybeSingle()` / `insert` / `update` |

### 5.4 Reports must not make N queries per student
The old code ran many small SQLite queries per student, which is fine locally but slow over the network. In `RankingService`:
1. Fetch **once per report**: active students, all `attendance` rows in the date range, all `hifd_entry` rows in the date range, and settings.
2. Compute `hodorScore`, `hifdScore`, `overallScore` in Dart with the **same formulas**:
   - `hodorScore = presentCount / totalDays * 100`
   - `hifdScore = avgGrade / 3 * 100`
   - `overallScore = hodorWeight * hodorScore + hifdWeight * hifdScore`
3. Same sorting and the same three outputs (`hodor_ranking`, `hifd_ranking`, `overall_ranking`).
4. `PdfService` input/output stays unchanged.
5. If the page limit of 1000 rows per request could be exceeded (term/total periods), paginate with `.range(from, to)` until all rows are fetched.

Acceptance: `grep -ri "sqflite\|openDatabase\|getDatabasesPath\|halaqati.db"` over `lib/` and `test/` returns nothing. Rankings for a sample dataset match the old app's numbers.

---

## 6. Phase 5: Real-time synchronization

Add stream methods to the service and expose them with `StreamProvider.autoDispose(.family)` in Riverpod:

```dart
Stream<List<Student>> watchStudents() => supabase
    .from('student')
    .stream(primaryKey: ['id'])
    .order('full_name')
    .map((rows) => rows.map(Student.fromJson).toList());

Stream<List<Attendance>> watchAttendance(String date) => supabase
    .from('attendance')
    .stream(primaryKey: ['id'])
    .eq('date', date)
    .map((rows) => rows.map(Attendance.fromJson).toList());
```

- Do the same for hifd entries (filter by `date`) and settings.
- RLS already restricts rows to the logged-in teacher, so no `teacher_id` filter is needed.
- A stream supports a single filter; do extra filtering (for example `active == true`) in Dart inside `.map`.
- Screens: `StudentsScreen`, `AttendanceScreen`, `HifdScreen`, `SettingsScreen` consume the stream providers. **Remove manual reload/refresh calls after saves.**
- `ReportsScreen`: rebuild when the student/attendance/hifd providers emit (or add a refresh button that invalidates the report provider).
- Autodispose providers so subscriptions are cancelled when screens close.
- Language setting: when `settings.language` changes in the cloud, the app locale updates on all devices.

Acceptance: with the same account on two devices, adding a student or marking attendance on one appears on the other within about 1-2 seconds, without manual refresh.

---

## 7. Phase 6: Cloud-only connectivity handling

### 7.1 Message (exact)
```
لا يوجد اتصال بالإنترنت
```

### 7.2 Implementation
1. `lib/core/network/connectivity_service.dart` using `connectivity_plus` -> `Stream<bool>` plus a Riverpod `connectivityProvider`. The plugin only reports the network interface, so **also** treat real request failures as offline.
2. `lib/core/errors/app_exception.dart` and an error mapper: `SocketException`, `TimeoutException`, `ClientException`/http connection failures, `AuthRetryableFetchException` -> `AppException.offline`; everything else -> `AppException.generic`.
3. Wrap every call in `SupabaseDataService` and `AuthService` with the mapper.
4. UI:
   - Global banner via `MaterialApp.builder` while offline, showing the message and a **إعادة المحاولة** button.
   - Failed write while offline: SnackBar with the same message. **Do not store or queue the write.** Keep the user's input in the form.
   - Failed initial screen load: centered message + retry button (invalidate the provider).
5. Do **not** add Hive, Drift, shared_preferences copies of data, or any local cache.
6. PDF generation and sharing need network only for data fetch; after the data is loaded they work as before.

Acceptance: airplane mode shows the banner; saving shows the message; reconnecting hides the banner and retry works; streams resume.

---

## 8. Phase 7: Remove Backup

Delete:
- `lib/screens/backup_screen.dart` (`BackUpScreen`) and the `/backup` route in `AppRoutes`.
- `lib/services/backup_service.dart` (`exportBackup`, `importBackup`, `exportDbFile`).
- Entry points to backup in `HomeScreen` / `SettingsScreen` / drawers.
- Backup-related l10n keys (ar/fr/en).
- `file_picker` usage and any file-export-only platform config (verify in `AndroidManifest.xml` / `Info.plist` before removing; keep what PDF sharing needs).

Do not touch `surah_aya.json`, `SurahCatalog`, `PdfService`.

Acceptance: no reference to backup/restore/export-db remains; app builds with no unused imports.

---

## 9. Phase 8: Preserved business rules

- Soft delete: `active = false`, history stays in reports.
- One attendance per student per day and one hifd entry per `student + date + type`: enforced by DB `unique` constraints and upserts.
- Historical read-only window: stays enforced in screen logic exactly as today (optional hardening on the server is out of scope).
- Default weights 0.4 / 0.6 and default language `ar`: from the `settings` defaults.

---

## 10. Phase 9: Security checklist

- [ ] `service_role` key is nowhere in the repo or app.
- [ ] URL and anon key come only from `--dart-define`.
- [ ] RLS enabled on all 5 tables; no policy for `anon`.
- [ ] Two-account isolation test: account B sees none of account A's data; B cannot insert a row with A's `student_id`.
- [ ] Logout clears in-memory provider state.

---

## 11. Phase 10: Tests and cleanup

1. Unit tests: model `fromJson/toJson`, error mapper, ranking computation (compare with fixtures from the old formulas).
2. Widget tests: LoginScreen validation, offline banner.
3. Manual E2E: sign up -> onboarding -> add students -> attendance -> hifd -> reports -> PDF -> two-device realtime -> offline message -> logout/login.
4. `flutter analyze` and `flutter test` clean.
5. Delete `AUDIT.md`, dead code, unused imports and l10n keys.

---

## 12. Optional: one-time import of existing local data

Only if the teacher already has data in the old app. Before removing Backup, export a JSON backup with the old app version. Then write a **throwaway** script (not shipped in the app) that reads the JSON, maps old integer IDs to new UUIDs (student first, then attendance and hifd_entry), and inserts them while logged in as the teacher. Delete the script afterwards.

---

## 13. README update

Rewrite the sections "Architectural summary", "Backup and Restore Architecture", "Data Persistence Design", "Business Rules (single-device)", "Technology Stack", "Setup and Run", and "Current limitations" to describe: cloud storage on Supabase, auth required, RLS, realtime sync, internet required, `--dart-define` run commands, backup removed, `surah_aya.json` bundled in the app.

---

## 14. Definition of done

- [ ] App starts at Login; session persists across restarts
- [ ] All data lives in Supabase; no SQLite code or package left
- [ ] RLS verified with two accounts
- [ ] Realtime works across two devices
- [ ] Offline shows `لا يوجد اتصال بالإنترنت`, no local cache
- [ ] Backup screen, service, route, strings removed
- [ ] `surah_aya.json` still bundled and used by `SurahCatalog`
- [ ] Rankings and PDFs produce the same results as before
- [ ] `flutter analyze` and `flutter test` pass
