import '../core/date_only.dart';

/// One memorization amount recorded for a student on a day.
///
/// Unique on `(student_id, date, type)`, so a save is an upsert. [type] is
/// `jadid` (new) or `muraja3a` (revision); [grade] is 3 / 2 / 1.
class HifdEntry {
  const HifdEntry({
    required this.studentId,
    required this.date,
    required this.type,
    required this.surahFrom,
    required this.ayahFrom,
    required this.surahTo,
    required this.ayahTo,
    required this.grade,
    this.id,
  });

  final String? id;
  final String studentId;
  final DateTime date;
  final String type;
  final int surahFrom;
  final int ayahFrom;
  final int surahTo;
  final int ayahTo;

  /// 3 = ممتاز, 2 = جيد, 1 = ضعيف.
  final int grade;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'student_id': studentId,
    'date': dateOnly(date),
    'type': type,
    'surah_from': surahFrom,
    'ayah_from': ayahFrom,
    'surah_to': surahTo,
    'ayah_to': ayahTo,
    'grade': grade,
  };

  factory HifdEntry.fromJson(Map<String, dynamic> json) => HifdEntry(
    id: json['id'] as String?,
    studentId: json['student_id'] as String? ?? '',
    date: parseDateOnly(json['date']) ?? DateTime.now(),
    type: json['type'] as String? ?? 'jadid',
    surahFrom: (json['surah_from'] as num?)?.toInt() ?? 1,
    ayahFrom: (json['ayah_from'] as num?)?.toInt() ?? 1,
    surahTo: (json['surah_to'] as num?)?.toInt() ?? 1,
    ayahTo: (json['ayah_to'] as num?)?.toInt() ?? 1,
    grade: (json['grade'] as num?)?.toInt() ?? 1,
  );
}
