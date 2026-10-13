import '../core/date_only.dart';

/// One student's attendance for one day. Unique on `(student_id, date)`, so a
/// save is an upsert.
class Attendance {
  const Attendance({
    required this.studentId,
    required this.date,
    required this.status,
    this.id,
  });

  /// `present` | `absent` | `late` | `excused`.
  final String status;
  final String? id;
  final String studentId;
  final DateTime date;

  static bool countsAsAttendance(String status) =>
      status == 'present' || status == 'late';

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'student_id': studentId,
    'date': dateOnly(date),
    'status': status,
  };

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    id: json['id'] as String?,
    studentId: json['student_id'] as String? ?? '',
    date: parseDateOnly(json['date']) ?? DateTime.now(),
    status: json['status'] as String? ?? 'absent',
  );
}
