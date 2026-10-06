import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance.dart';
import '../models/hifd_entry.dart';
import '../models/settings.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../services/auth_service.dart';
import '../services/ranking_service.dart';
import '../services/supabase_data_service.dart';
import 'date_only.dart';
import 'network/connectivity_service.dart';

// ------------------------------------------------------------------ services

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final dataServiceProvider = Provider<SupabaseDataService>(
  (ref) => SupabaseDataService(),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// Whether the device currently reports a network interface.
///
/// A hint only: a request can still fail while this is `true`, which is why
/// failures are also mapped to an offline state.
final onlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).watch(),
);

// ---------------------------------------------------------------------- auth

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).onAuthStateChange,
);

/// `null` until `supabase_flutter` has restored a persisted session, then the
/// signed-in user or `null` again after logout.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  if (!state.hasValue) return null;
  return state.value?.session?.user;
});

// ------------------------------------------------------------------- account

/// The teacher row, or `null` before onboarding. Drives the root routing:
/// no session -> login, no teacher -> onboarding, teacher -> home.
final teacherProvider = FutureProvider<Teacher?>(
  (ref) => ref.watch(dataServiceProvider).getTeacher(),
);

// ------------------------------------------------------------------ settings

/// Live preferences. Because this is a realtime subscription, changing the
/// appearance on one device changes it on every other signed-in device.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(dataServiceProvider).watchSettings(),
);

/// Convenience for the many `AsyncValue.valueOrNull ?? const AppSettings()`
/// call sites.
final settingsValueProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsProvider).valueOrNull ?? const AppSettings(),
);

// ------------------------------------------------------------------- students

/// Every student, active or not, ordered by name. Callers filter `active`
/// themselves because a realtime subscription carries a single filter.
final studentsProvider = StreamProvider<List<Student>>(
  (ref) => ref.watch(dataServiceProvider).watchStudents(),
);

final activeStudentsProvider = Provider<List<Student>>(
  (ref) =>
      ref
          .watch(studentsProvider)
          .valueOrNull
          ?.where((s) => s.active)
          .toList() ??
      const <Student>[],
);

// ---------------------------------------------------------------- attendance

final attendanceProvider = StreamProvider.family<List<Attendance>, String>(
  (ref, date) => ref.watch(dataServiceProvider).watchAttendance(date),
);

// ---------------------------------------------------------------------- hifd

final hifdEntriesProvider = StreamProvider.family<List<HifdEntry>, String>(
  (ref, date) => ref.watch(dataServiceProvider).watchHifdEntries(date),
);

/// Dates whose memorization register has been confirmed and frozen.
final lockedHifdDaysProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(dataServiceProvider).watchLockedHifdDays(),
);

// ----------------------------------------------------------------- reporting

/// Everything a report needs for one period, fetched in three parallel round
/// trips instead of three per student.
final reportDataProvider =
    FutureProvider.family<ReportData, ({DateTime start, DateTime end})>((
      ref,
      period,
    ) async {
      final db = ref.watch(dataServiceProvider);
      final (students, attendance, hifdEntries) = await (
        db.getStudents(active: true),
        db.getAttendanceRange(period.start, period.end),
        db.getHifdRange(period.start, period.end),
      ).wait;
      return ReportData(
        students: students,
        attendance: attendance,
        hifdEntries: hifdEntries,
      );
    });

/// Raw rows for one reporting period.
class ReportData {
  const ReportData({
    required this.students,
    required this.attendance,
    required this.hifdEntries,
  });

  final List<Student> students;
  final List<Attendance> attendance;
  final List<HifdEntry> hifdEntries;

  Map<String, dynamic> rankings(
    AppSettings settings,
    DateTime start,
    DateTime end,
  ) => RankingService.computeRankings(
    students: students,
    attendance: attendance,
    hifdEntries: hifdEntries,
    settings: settings,
    start: start,
    end: end,
  );
}

/// Drops every cached row so a signed-out account can never leak its data into
/// the next one. Called on logout.
void invalidateAccountData(WidgetRef ref) {
  ref.invalidate(studentsProvider);
  ref.invalidate(attendanceProvider);
  ref.invalidate(hifdEntriesProvider);
  ref.invalidate(lockedHifdDaysProvider);
  ref.invalidate(settingsProvider);
  ref.invalidate(reportDataProvider);
}

/// Today as `yyyy-MM-dd`, the key format the family providers use.
String todayKey() => dateOnly(DateTime.now());
