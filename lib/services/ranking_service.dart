import '../core/date_only.dart';
import '../models/attendance.dart';
import '../models/hifd_entry.dart';
import '../models/settings.dart';
import '../models/student.dart';
import 'dart:math' as math;

/// Aggregates saved attendance and Hifdh records for reports.
class RankingService {
  const RankingService._();

 /// Hifd score = 70% quality (avg grade) + 30% volume (records vs. the
/// most active student in the same period). Prevents "1 perfect record"
/// from beating a student who memorised a lot.
static const double _qualityWeight = 0.7;
static const double _volumeWeight = 0.3;

static Map<String, dynamic> computeRankings({
  required List<Student> students,
  required List<Attendance> attendance,
  required List<HifdEntry> hifdEntries,
  required AppSettings settings,
  required DateTime start,
  required DateTime end,
}) {
  final attendanceByStudent = _attendanceSummary(attendance, start, end);
  final hifdhByStudent = _hifdhSummary(hifdEntries, start, end);
  final active = students.where((s) => s.active).toList();

  final maxRecords = active.fold<int>(
    0,
    (m, s) => math.max(m, (hifdhByStudent[s.id]?['hifdh_records'] as int?) ?? 0),
  );

  final rankings = <Map<String, dynamic>>[];
  for (final student in active) {
    final att = attendanceByStudent[student.id] ?? _emptyAttendance();
    final hifdh = hifdhByStudent[student.id] ?? _emptyHifdh();
    final expected = att['expected_sessions'] as int;
    final attended = att['attended'] as int;
    final records = hifdh['hifdh_records'] as int;
    final avgGrade = hifdh['avg_grade'] as double;

    final hodorScore = expected == 0 ? 0.0 : attended / expected * 100;
    final quality = avgGrade == 0 ? 0.0 : avgGrade / 3 * 100;
    final volume = maxRecords == 0 ? 0.0 : records / maxRecords * 100;
    final hifdScore = records == 0
        ? 0.0
        : quality * _qualityWeight + volume * _volumeWeight;

    rankings.add({
      'student': student,
      ...att,
      ...hifdh,
      'hodor_score': hodorScore,
      'attendance_rate': hodorScore,
      'hifd_quality': quality,
      'hifd_volume': volume,
      'hifd_score': hifdScore,
      'overall_score':
          settings.hodorWeight * hodorScore + settings.hifdWeight * hifdScore,
      'total_days': expected,
    });
  }

  final hodorRanking = _sorted(rankings,
      scoreKey: 'hodor_score',
      secondaryKeys: const ['expected_sessions', 'attended', 'hifdh_records']);
  final hifdRanking = _sorted(rankings,
      scoreKey: 'hifd_score',
      secondaryKeys: const ['hifdh_records', 'hifdh_sessions']);
  final overallRanking = _sorted(rankings,
      scoreKey: 'overall_score',
      secondaryKeys: const ['expected_sessions', 'attended', 'hifdh_records']);

  // Same map objects are shared, so each student carries all three ranks.
  for (var i = 0; i < hodorRanking.length; i++) {
    hodorRanking[i]['hodor_rank'] = i + 1;
  }
  for (var i = 0; i < hifdRanking.length; i++) {
    hifdRanking[i]['hifd_rank'] = i + 1;
  }
  for (var i = 0; i < overallRanking.length; i++) {
    overallRanking[i]['overall_rank'] = i + 1;
  }

  return {
    'hodor_ranking': hodorRanking,
    'hifd_ranking': hifdRanking,
    'overall_ranking': overallRanking,
    'total_sessions': _distinctSessionDates(attendance, start, end).length,
  };
}
  /// Student-level figures and chronological Hifdh history for the period.
  static Map<String, dynamic> studentReport({
    required Student? student,
    required List<Attendance> attendance,
    required List<HifdEntry> hifdEntries,
    required AppSettings settings,
    required DateTime start,
    required DateTime end,
  }) {
    final id = student?.id;
    final attendanceSummary = id == null
        ? _emptyAttendance()
        : _attendanceSummary(attendance, start, end)[id] ?? _emptyAttendance();
    final hifdhSummary = id == null
        ? _emptyHifdh()
        : _hifdhSummary(hifdEntries, start, end)[id] ?? _emptyHifdh();
    final hodorScore = attendanceSummary['expected_sessions'] == 0
        ? 0.0
        : (attendanceSummary['attended'] as int) /
              (attendanceSummary['expected_sessions'] as int) *
              100;
    final avgGrade = hifdhSummary['avg_grade'] as double;
    final hifdScore = avgGrade == 0 ? 0.0 : avgGrade / 3 * 100;

    return {
      'student': student,
      ...attendanceSummary,
      ...hifdhSummary,
      'hodor_score': hodorScore,
      'attendance_rate': hodorScore,
      'hifd_score': hifdScore,
      'overall_score':
          settings.hodorWeight * hodorScore + settings.hifdWeight * hifdScore,
      'total_days': attendanceSummary['expected_sessions'],
    };
  }

  static Map<String, dynamic> _emptyAttendance() => {
    'present': 0,
    'late': 0,
    'attended': 0,
    'absent': 0,
    'excused': 0,
    'expected_sessions': 0,
    'status_counts': <String, int>{},
  };

  static Map<String, dynamic> _emptyHifdh() => {
  'avg_grade': 0.0,
  'hifdh_records': 0,
  'hifdh_sessions': 0,
  'hifdh_ayahs': 0,
  'grade_counts': <int, int>{},
  'type_counts': <String, int>{},
  'last_hifdh_date': null,
  'surahs': <int>[],
  'hifd_ranges': <Map<String, dynamic>>[],
};

  /// A single saved status per student/day; conflicting duplicate days resolve
  /// deterministically, while the database's unique key normally prevents them.
  static Map<String, Map<String, dynamic>> _attendanceSummary(
    List<Attendance> rows,
    DateTime start,
    DateTime end,
  ) {
    final statusByDay = <String, Map<String, String>>{};
    for (final row in rows) {
      if (!dateInRange(row.date, start, end) || row.studentId.isEmpty) continue;
      final day = dateOnly(row.date);
      final statuses = statusByDay.putIfAbsent(
        row.studentId,
        () => <String, String>{},
      );
      final current = statuses[day];
      if (current == null || _statusOrder(row.status) < _statusOrder(current)) {
        statuses[day] = row.status;
      }
    }

    return {
      for (final studentEntry in statusByDay.entries)
        studentEntry.key: _summarizeStatuses(studentEntry.value.values),
    };
  }

  static Map<String, dynamic> _summarizeStatuses(Iterable<String> statuses) {
    final counts = <String, int>{};
    for (final status in statuses) {
      counts.update(status, (count) => count + 1, ifAbsent: () => 1);
    }
    final present = counts['present'] ?? 0;
    final late = counts['late'] ?? 0;
    final expected = statuses.where((status) => status != 'excused').length;
    return {
      'present': present,
      'late': late,
      'attended': present + late,
      'absent': counts['absent'] ?? 0,
      'excused': counts['excused'] ?? 0,
      'expected_sessions': expected,
      'status_counts': counts,
    };
  }

  static int _statusOrder(String status) => switch (status) {
    'present' => 0,
    'late' => 1,
    'absent' => 2,
    'excused' => 3,
    _ => 4,
  };

  static Map<String, Map<String, dynamic>> _hifdhSummary(
    List<HifdEntry> rows,
    DateTime start,
    DateTime end,
  ) {
    final byStudent = <String, List<HifdEntry>>{};
    for (final row in rows) {
      if (!dateInRange(row.date, start, end) || row.studentId.isEmpty) continue;
      byStudent.putIfAbsent(row.studentId, () => <HifdEntry>[]).add(row);
    }

    return {
      for (final studentEntry in byStudent.entries)
        studentEntry.key: _summarizeHifdh(studentEntry.value),
    };
  }

 static Map<String, dynamic> _summarizeHifdh(List<HifdEntry> entries) {
  final ordered = entries.toList()
    ..sort((a, b) {
      final d = a.date.compareTo(b.date);
      if (d != 0) return d;
      final s = a.surahFrom.compareTo(b.surahFrom);
      if (s != 0) return s;
      return a.ayahFrom.compareTo(b.ayahFrom);
    });
  final surahs = <int>{
    for (final e in ordered) e.surahFrom,
    for (final e in ordered) e.surahTo,
  }.toList()..sort();

  final gradeCounts = <int, int>{};
  final typeCounts = <String, int>{};
  var ayahs = 0;
  for (final e in ordered) {
    gradeCounts.update(e.grade, (c) => c + 1, ifAbsent: () => 1);
    typeCounts.update(e.type, (c) => c + 1, ifAbsent: () => 1);
    // Exact for single-surah ranges. For ranges crossing surahs, plug in
    // your surah ayah counts here if SurahCatalog exposes them.
    if (e.surahFrom == e.surahTo) {
      ayahs += math.max(0, e.ayahTo - e.ayahFrom + 1);
    }
  }

  return {
    'avg_grade':
        ordered.fold<int>(0, (t, e) => t + e.grade) / ordered.length,
    'hifdh_records': ordered.length,
    'hifdh_sessions': ordered.map((e) => dateOnly(e.date)).toSet().length,
    'hifdh_ayahs': ayahs,
    'grade_counts': gradeCounts,
    'type_counts': typeCounts,
    'last_hifdh_date': dateOnly(ordered.last.date),
    'surahs': surahs,
    'hifd_ranges': ordered.map(_hifdRange).toList(),
  };
}
  static Set<String> _distinctSessionDates(
    List<Attendance> rows,
    DateTime start,
    DateTime end,
  ) => {
    for (final row in rows)
      if (row.status != 'excused' &&
          row.studentId.isNotEmpty &&
          dateInRange(row.date, start, end))
        dateOnly(row.date),
  };

  /// Fair ordering: score first, then more marked/attended sessions and
  /// memorization records; student name and ID make ties deterministic.
  static List<Map<String, dynamic>> _sorted(
    List<Map<String, dynamic>> entries, {
    required String scoreKey,
    required List<String> secondaryKeys,
  }) =>
      entries.toList()..sort((a, b) {
        final scoreOrder =
            (b[scoreKey] as double).compareTo(a[scoreKey] as double);
        if (scoreOrder != 0) return scoreOrder;
        for (final key in secondaryKeys) {
          final order = (b[key] as int).compareTo(a[key] as int);
          if (order != 0) return order;
        }
        final nameOrder = (a['student'] as Student).fullName.compareTo(
          (b['student'] as Student).fullName,
        );
        if (nameOrder != 0) return nameOrder;
        return ((a['student'] as Student).id ?? '').compareTo(
          (b['student'] as Student).id ?? '',
        );
      });

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
