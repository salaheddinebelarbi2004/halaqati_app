import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/date_only.dart';
import '../core/errors/app_exception.dart';
import '../models/attendance.dart';
import '../models/hifd_entry.dart';
import '../models/settings.dart';
import '../models/student.dart';
import '../models/teacher.dart';

/// Cloud replacement for the old SQLite `DatabaseService`.
///
/// Every call goes through Supabase (PostgREST + RLS). The client never sends
/// `teacher_id`: the column default is `auth.uid()` and RLS rejects anything
/// else. Every method funnels failures through [guard] so the UI only ever
/// sees an [AppException].
class SupabaseDataService {
  SupabaseDataService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// PostgREST caps a response at 1000 rows; anything larger must be paged.
  static const int pageSize = 1000;

  // ---------------------------------------------------------------- teacher

  /// The teacher row for the signed-in account, or `null` before onboarding.
  Future<Teacher?> getTeacher() => guard(() async {
    final rows = await _client.from('teacher').select().limit(1);
    if (rows.isEmpty) return null;
    return Teacher.fromJson(rows.first);
  });

  /// Inserts the teacher row on first run and updates it afterwards.
  Future<void> saveTeacher(Teacher teacher) => guard(() async {
    await _client.from('teacher').upsert(teacher.toJson());
  });

  // --------------------------------------------------------------- students

  Future<List<Student>> getStudents({bool? active}) => guard(() async {
    var query = _client.from('student').select();
    if (active != null) query = query.eq('active', active);
    final rows = await query.order('full_name');
    return rows.map(Student.fromJson).toList();
  });

  Future<Student?> getStudent(String id) => guard(() async {
    final rows = await _client.from('student').select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return Student.fromJson(rows.first);
  });

  Future<Student> insertStudent(Student student) => guard(() async {
    final rows = await _client
        .from('student')
        .insert(student.toJson())
        .select()
        .single();
    return Student.fromJson(rows);
  });

  Future<void> updateStudent(Student student) => guard(() async {
    final id = student.id;
    if (id == null) throw ArgumentError('student.id is required to update');
    await _client.from('student').update(student.toJson()).eq('id', id);
  });

  /// Soft delete: the row stays so historical reports keep working.
  Future<void> deactivateStudent(String id) => guard(() async {
    await _client.from('student').update({'active': false}).eq('id', id);
  });

  // ------------------------------------------------------------- attendance

  Future<List<Attendance>> getAttendanceForDate(DateTime date) =>
      guard(() async {
        final rows = await _client
            .from('attendance')
            .select()
            .eq('date', dateOnly(date));
        return rows.map(Attendance.fromJson).toList();
      });

  /// One round trip for the whole session, relying on
  /// `UNIQUE(student_id, date)` to overwrite instead of duplicating.
  Future<void> saveAttendance(List<Attendance> rows) => guard(() async {
    if (rows.isEmpty) return;
    await _client
        .from('attendance')
        .upsert(
          rows.map((r) => r.toJson()).toList(),
          onConflict: 'student_id,date',
        );
  });

  // ------------------------------------------------------------------- hifd

  Future<List<HifdEntry>> getHifdForDate(DateTime date) => guard(() async {
    final rows = await _client
        .from('hifd_entry')
        .select()
        .eq('date', dateOnly(date));
    return rows.map(HifdEntry.fromJson).toList();
  });

  Future<void> saveHifdEntry(HifdEntry entry) => guard(() async {
    await _client
        .from('hifd_entry')
        .upsert(entry.toJson(), onConflict: 'student_id,date,type');
  });

  // -------------------------------------------------------- memorization lock

  /// Dates whose memorization register has been confirmed and frozen.
  Future<Set<String>> getLockedHifdDays() => guard(() async {
    final rows = await _paged('hifd_day_lock');
    return {for (final row in rows) row['date'] as String};
  });

  Future<void> lockHifdDay(DateTime date) => guard(() async {
    await _client.from('hifd_day_lock').upsert({
      'date': dateOnly(date),
      'locked_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  Future<void> unlockHifdDay(DateTime date) => guard(() async {
    await _client.from('hifd_day_lock').delete().eq('date', dateOnly(date));
  });

  // --------------------------------------------------------------- settings

  /// The settings row created by the `teacher` insert trigger. Falls back to
  /// defaults while onboarding has not run yet.
  Future<AppSettings> getSettings() => guard(() async {
    final rows = await _client.from('settings').select().limit(1);
    if (rows.isEmpty) return const AppSettings();
    return AppSettings.fromJson(rows.first);
  });

  Future<void> saveWeights({required double hodor, required double hifd}) =>
      guard(() async {
        await _client
            .from('settings')
            .update({'hodor_weight': hodor, 'hifd_weight': hifd})
            .eq('teacher_id', _uid());
      });

  Future<void> saveThemeMode(String mode) => guard(() async {
    await _client
        .from('settings')
        .update({'theme_mode': mode})
        .eq('teacher_id', _uid());
  });

  // --------------------------------------------------------------- reporting

  /// Every attendance row in `[start, end]`, paged past the 1000-row cap.
  Future<List<Attendance>> getAttendanceRange(DateTime start, DateTime end) =>
      guard(() async {
        final rows = await _paged('attendance', start: start, end: end);
        return rows.map(Attendance.fromJson).toList();
      });

  /// Every memorization row in `[start, end]`, paged.
  Future<List<HifdEntry>> getHifdRange(DateTime start, DateTime end) =>
      guard(() async {
        final rows = await _paged('hifd_entry', start: start, end: end);
        return rows.map(HifdEntry.fromJson).toList();
      });

  // --------------------------------------------------------------- realtime

  /// All students, active or not — callers filter in Dart, because a realtime
  /// subscription carries a single filter.
  Stream<List<Student>> watchStudents() => _client
      .from('student')
      .stream(primaryKey: ['id'])
      .order('full_name')
      .map((rows) => rows.map(Student.fromJson).toList())
      .guarded();

  Stream<List<Attendance>> watchAttendance(String date) => _client
      .from('attendance')
      .stream(primaryKey: ['id'])
      .eq('date', date)
      .map((rows) => rows.map(Attendance.fromJson).toList())
      .guarded();

  Stream<List<HifdEntry>> watchHifdEntries(String date) => _client
      .from('hifd_entry')
      .stream(primaryKey: ['id'])
      .eq('date', date)
      .map((rows) => rows.map(HifdEntry.fromJson).toList())
      .guarded();

  Stream<AppSettings> watchSettings() => _client
      .from('settings')
      .stream(primaryKey: ['teacher_id'])
      .map(
        (rows) => rows.isEmpty
            ? const AppSettings()
            : AppSettings.fromJson(rows.first),
      )
      .guarded();

  Stream<Set<String>> watchLockedHifdDays() => _client
      .from('hifd_day_lock')
      .stream(primaryKey: ['date'])
      .map((rows) => {for (final row in rows) row['date'] as String})
      .guarded();

  // ---------------------------------------------------------------- helpers

  String _uid() => _client.auth.currentUser!.id;

  /// Reads a whole table (optionally a date range) one page at a time.
  Future<List<Map<String, dynamic>>> _paged(
    String table, {
    DateTime? start,
    DateTime? end,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (var from = 0; ; from += pageSize) {
      var query = _client.from(table).select();
      if (start != null) query = query.gte('date', dateOnly(start));
      if (end != null) query = query.lte('date', dateOnly(end));
      final rows = await query.range(from, from + pageSize - 1);
      all.addAll(rows);
      if (rows.length < pageSize) return all;
    }
  }
}
