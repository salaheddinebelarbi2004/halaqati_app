import '../core/date_only.dart';
import '../models/attendance.dart';
import '../models/hifd_entry.dart';
import '../models/settings.dart';
import '../models/student.dart';

/// Turns raw rows into the three rankings the reports screen shows.
///
/// Pure Dart on purpose: the old implementation issued four queries *per
/// student*, which is free against SQLite and ruinous over the network. The
/// caller now fetches the period's attendance and memorization rows once and
/// hands them in.
///
/// The formulas are unchanged:
///
/// ```
/// hodorScore   = presentCount / totalDays * 100
/// hifdScore    = avgGrade / 3 * 100
/// overallScore = hodorWeight * hodorScore + hifdWeight * hifdScore
/// ```
///
/// [totalDays] is *not* the session count. It is the number of distinct days
/// on which this student has a row that is not `excused`; `excused` days are
/// deliberately excluded from the denominator but `absent` and `late` days are
/// not. `total_sessions`, by contrast, counts every distinct day in the period
/// across all students and all statuses.
class RankingService {
  const RankingService._();

  static Map<String, dynamic> computeRankings({
    required List<Student> students,
    required List<Attendance> attendance,
    required List<HifdEntry> hifdEntries,
    required AppSettings settings,
    required DateTime start,
    required DateTime end,
  }) {
    final presentByStudent = _presentCounts(attendance, start, end);
    final daysByStudent = _sessionDays(attendance, start, end);
    final gradeByStudent = _averageGrades(hifdEntries, start, end);

    var hodorRanking = <Map<String, dynamic>>[];
    var hifdRanking = <Map<String, dynamic>>[];
    var overallRanking = <Map<String, dynamic>>[];

    for (final student in students.where((s) => s.active)) {
      final presentCount = presentByStudent[student.id] ?? 0;
      final totalDays = daysByStudent[student.id] ?? 0;
      final avgGrade = gradeByStudent[student.id] ?? 0.0;

      final hodorScore = totalDays > 0 ? (presentCount / totalDays) * 100 : 0.0;
      final hifdScore = avgGrade > 0 ? (avgGrade / 3) * 100 : 0.0;
      final overallScore =
          (settings.hodorWeight * hodorScore) +
          (settings.hifdWeight * hifdScore);

      final entry = <String, dynamic>{
        'student': student,
        'hodor_score': hodorScore,
        'hifd_score': hifdScore,
        'overall_score': overallScore,
        'present': presentCount,
        'total_days': totalDays,
        'avg_grade': avgGrade,
      };

      hodorRanking.add(entry);
      hifdRanking.add(entry);
      overallRanking.add(entry);
    }

    hodorRanking = _sorted(hodorRanking, 'hodor_score');
    hifdRanking = _sorted(hifdRanking, 'hifd_score');
    overallRanking = _sorted(overallRanking, 'overall_score');

    return {
      'hodor_ranking': hodorRanking,
      'hifd_ranking': hifdRanking,
      'overall_ranking': overallRanking,
      'total_sessions': _distinctDates(attendance, start, end).length,
    };
  }

  /// Per-student summary plus the memorization history rows the detail screen
  /// lists.
  static Map<String, dynamic> studentReport({
    required Student? student,
    required List<Attendance> attendance,
    required List<HifdEntry> hifdEntries,
    required AppSettings settings,
    required DateTime start,
    required DateTime end,
  }) {
    final id = student?.id;
    final presentCount = id == null
        ? 0
        : _presentCounts(attendance, start, end)[id] ?? 0;
    final totalDays = id == null
        ? 0
        : _sessionDays(attendance, start, end)[id] ?? 0;
    final avgGrade = id == null
        ? 0.0
        : _averageGrades(hifdEntries, start, end)[id] ?? 0.0;

    final hodorScore = totalDays > 0 ? (presentCount / totalDays) * 100 : 0.0;
    final hifdScore = avgGrade > 0 ? (avgGrade / 3) * 100 : 0.0;

    final ranges = id == null
        ? <Map<String, dynamic>>[]
        : (hifdEntries
                  .where(
                    (e) => e.studentId == id && dateInRange(e.date, start, end),
                  )
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date)))
              .map(_hifdRange)
              .toList();

    return {
      'student': student,
      'hodor_score': hodorScore,
      'hifd_score': hifdScore,
      'overall_score':
          (settings.hodorWeight * hodorScore) +
          (settings.hifdWeight * hifdScore),
      'present': presentCount,
      'total_days': totalDays,
      'avg_grade': avgGrade,
      'hifd_ranges': ranges,
    };
  }

  // ------------------------------------------------------------- aggregation

  /// `student id -> number of 'present' rows in the period`.
  static Map<String?, int> _presentCounts(
    List<Attendance> rows,
    DateTime start,
    DateTime end,
  ) {
    final counts = <String?, int>{};
    for (final row in rows) {
      if (row.status != 'present') continue;
      if (!dateInRange(row.date, start, end)) continue;
      counts.update(row.studentId, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// `student id -> distinct days with a non-excused row in the period`.
  static Map<String?, int> _sessionDays(
    List<Attendance> rows,
    DateTime start,
    DateTime end,
  ) {
    final days = <String?, Set<String>>{};
    for (final row in rows) {
      if (row.status == 'excused') continue;
      if (!dateInRange(row.date, start, end)) continue;
      (days[row.studentId] ??= <String>{}).add(dateOnly(row.date));
    }
    return {for (final e in days.entries) e.key: e.value.length};
  }

  /// `student id -> mean grade over the period`, absent when there are no rows.
  static Map<String?, double> _averageGrades(
    List<HifdEntry> rows,
    DateTime start,
    DateTime end,
  ) {
    final totals = <String?, int>{};
    final counts = <String?, int>{};
    for (final row in rows) {
      if (!dateInRange(row.date, start, end)) continue;
      totals.update(
        row.studentId,
        (v) => v + row.grade,
        ifAbsent: () => row.grade,
      );
      counts.update(row.studentId, (v) => v + 1, ifAbsent: () => 1);
    }
    return {for (final e in totals.entries) e.key: e.value / counts[e.key]!};
  }

  /// Every distinct day in the period, any student, any status.
  static Set<String> _distinctDates(
    List<Attendance> rows,
    DateTime start,
    DateTime end,
  ) => {
    for (final row in rows)
      if (dateInRange(row.date, start, end)) dateOnly(row.date),
  };

  static List<Map<String, dynamic>> _sorted(
    List<Map<String, dynamic>> entries,
    String key,
  ) =>
      entries.toList()
        ..sort((a, b) => (b[key] as double).compareTo(a[key] as double));

  /// Shape consumed by the detail screen's `_HifdRangeRow`.
  static Map<String, dynamic> _hifdRange(HifdEntry entry) => {
    'surah_from': entry.surahFrom,
    'ayah_from': entry.ayahFrom,
    'surah_to': entry.surahTo,
    'ayah_to': entry.ayahTo,
    'type': entry.type,
    'grade': entry.grade,
    'date': dateOnly(entry.date),
  };
}
