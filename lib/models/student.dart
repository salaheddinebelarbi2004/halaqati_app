import '../core/date_only.dart';

/// A pupil of the halaqa. [id] is a UUID assigned by Postgres; `teacher_id` is
/// never sent by the client.
class Student {
  const Student({
    required this.fullName,
    this.id,
    this.birthDate,
    this.guardianPhone,
    this.enrollmentDate,
    this.active = true,
    this.notes,
  });

  final String? id;
  final String fullName;
  final DateTime? birthDate;
  final String? guardianPhone;
  final DateTime? enrollmentDate;
  final bool active;
  final String? notes;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'full_name': fullName,
    'birth_date': birthDate == null ? null : dateOnly(birthDate!),
    'guardian_phone': guardianPhone,
    'enrollment_date': enrollmentDate == null
        ? null
        : dateOnly(enrollmentDate!),
    'active': active,
    'notes': notes,
  };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as String?,
    fullName: json['full_name'] as String? ?? '',
    birthDate: parseDateOnly(json['birth_date']),
    guardianPhone: json['guardian_phone'] as String?,
    enrollmentDate: parseDateOnly(json['enrollment_date']),
    active: json['active'] as bool? ?? true,
    notes: json['notes'] as String?,
  );

  Student copyWith({
    String? id,
    String? fullName,
    DateTime? birthDate,
    String? guardianPhone,
    DateTime? enrollmentDate,
    bool? active,
    String? notes,
  }) => Student(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    birthDate: birthDate ?? this.birthDate,
    guardianPhone: guardianPhone ?? this.guardianPhone,
    enrollmentDate: enrollmentDate ?? this.enrollmentDate,
    active: active ?? this.active,
    notes: notes ?? this.notes,
  );
}
