import 'package:flutter_test/flutter_test.dart';
import 'package:halaqati/models/attendance.dart';
import 'package:halaqati/models/hifd_entry.dart';
import 'package:halaqati/models/settings.dart';
import 'package:halaqati/models/student.dart';
import 'package:halaqati/services/ranking_service.dart';

/// These tests exist because the denominators are easy to "fix" by accident.
/// `total_days` is NOT the session count and NOT the number of present days:
/// it is the number of distinct days on which the student has any row that is
/// not `excused`, so `absent` and `late` both count against them.
void main() {
  final start = DateTime(2025, 1, 1);
  final end = DateTime(2025, 1, 31);

  const ali = Student(id: 'a', fullName: 'علي');
  const sara = Student(id: 's', fullName: 'سارة');
  const inactive = Student(id: 'i', fullName: 'موقوف', active: false);

  Attendance att(String student, int day, String status) => Attendance(
    studentId: student,
    date: DateTime(2025, 1, day),
    status: status,
  );

  HifdEntry hifd(String student, int day, int grade) => HifdEntry(
    studentId: student,
    date: DateTime(2025, 1, day),
    type: 'jadid',
    surahFrom: 1,
    ayahFrom: 1,
    surahTo: 1,
    ayahTo: 5,
    grade: grade,
  );

  Map<String, dynamic> rankings({
    List<Attendance> attendance = const [],
    List<HifdEntry> hifdEntries = const [],
    List<Student> students = const [ali, sara],
    AppSettings settings = const AppSettings(),
  }) => RankingService.computeRankings(
    students: students,
    attendance: attendance,
    hifdEntries: hifdEntries,
    settings: settings,
    start: start,
    end: end,
  );

  Map<String, dynamic> entryAt(
    Map<String, dynamic> result,
    String key,
    String id,
  ) => (result[key] as List).cast<Map<String, dynamic>>().firstWhere(
    (e) => (e['student'] as Student).id == id,
  );

  group('total_days excludes excused days but not absent ones', () {
    test('absent and late both count as a session', () {
      final result = rankings(
        attendance: [att('a', 1, 'present'), att('a', 2, 'absent')],
      );
      final row = entryAt(result, 'hodor_ranking', 'a');
      expect(row['total_days'], 2);
      expect(row['present'], 1);
      expect(row['hodor_score'], closeTo(50, 0.001));
    });

    test('an excused day is not a session', () {
      final result = rankings(
        attendance: [
          att('a', 1, 'present'),
          att('a', 2, 'present'),
          att('a', 3, 'excused'),
        ],
      );
      final row = entryAt(result, 'hodor_ranking', 'a');
      expect(row['total_days'], 2);
      expect(row['present'], 2);
      expect(row['hodor_score'], 100);
    });

    test('a student with no rows scores 0 rather than dividing by zero', () {
      final result = rankings();
      final row = entryAt(result, 'hodor_ranking', 'a');
      expect(row['total_days'], 0);
      expect(row['hodor_score'], 0);
      expect(row['avg_grade'], 0);
      expect(row['hifd_score'], 0);
      expect(row['overall_score'], 0);
    });
  });

  group('total_sessions counts every day in the period', () {
    test('including excused days and other students', () {
      final result = rankings(
        attendance: [
          att('a', 1, 'present'),
          att('a', 1, 'absent'),
          att('s', 1, 'excused'),
          att('s', 2, 'present'),
        ],
      );
      expect(result['total_sessions'], 2);
    });

    test('ignoring rows outside the period', () {
      final result = rankings(
        attendance: [
          att('a', 1, 'present'),
          Attendance(
            studentId: 'a',
            date: DateTime(2024, 12, 31),
            status: 'present',
          ),
        ],
      );
      expect(result['total_sessions'], 1);
    });
  });

  group('memorization average', () {
    test('is the mean grade, scored out of 3', () {
      final result = rankings(hifdEntries: [hifd('a', 1, 3), hifd('a', 2, 2)]);
      final row = entryAt(result, 'hifd_ranking', 'a');
      expect(row['avg_grade'], 2.5);
      expect(row['hifd_score'], closeTo(2.5 / 3 * 100, 0.001));
    });
  });

  group('overall score applies the stored weights', () {
    test('default 0.4 / 0.6', () {
      final result = rankings(
        attendance: [att('a', 1, 'present'), att('a', 2, 'absent')],
        hifdEntries: [hifd('a', 1, 3)],
        students: const [ali],
      );
      final row = entryAt(result, 'overall_ranking', 'a');
      expect(row['overall_score'], closeTo(0.4 * 50 + 0.6 * 100, 0.001));
    });

    test('weights are read from settings, not hard-coded', () {
      final result = rankings(
        attendance: [att('a', 1, 'present'), att('a', 2, 'absent')],
        hifdEntries: [hifd('a', 1, 3)],
        students: const [ali],
        settings: const AppSettings(hodorWeight: 1, hifdWeight: 0),
      );
      final row = entryAt(result, 'overall_ranking', 'a');
      expect(row['overall_score'], closeTo(50, 0.001));
    });
  });

  group('ranking', () {
    test('sorts each list by its own score, descending', () {
      final result = rankings(
        attendance: [att('a', 1, 'present'), att('s', 1, 'absent')],
        hifdEntries: [hifd('a', 1, 3), hifd('s', 1, 1)],
      );
      final hodor = (result['hodor_ranking'] as List)
          .cast<Map<String, dynamic>>();
      final hifdRank = (result['hifd_ranking'] as List)
          .cast<Map<String, dynamic>>();
      expect((hodor.first['student'] as Student).id, 'a');
      expect((hifdRank.first['student'] as Student).id, 'a');
    });

    test('inactive students are left out entirely', () {
      final result = rankings(
        attendance: [att('a', 1, 'present'), att('i', 1, 'present')],
        students: const [ali, inactive],
      );
      expect(result['hodor_ranking'], hasLength(1));
    });
  });
}
