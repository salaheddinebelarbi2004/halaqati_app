/// The teacher who owns this account. One account = one halaqa.
///
/// [id] is the Supabase auth user id (`auth.uid()`), never chosen by the
/// client: the column default supplies it.
class Teacher {
  const Teacher({
    required this.name,
    required this.madrassaName,
    required this.halaqaName,
    this.id,
    this.phone,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String madrassaName;
  final String halaqaName;
  final String? phone;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'madrassa_name': madrassaName,
    'halaqa_name': halaqaName,
    'phone': phone,
  };

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    madrassaName: json['madrassa_name'] as String? ?? '',
    halaqaName: json['halaqa_name'] as String? ?? '',
    phone: json['phone'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Teacher copyWith({
    String? id,
    String? name,
    String? madrassaName,
    String? halaqaName,
    String? phone,
    DateTime? createdAt,
  }) => Teacher(
    id: id ?? this.id,
    name: name ?? this.name,
    madrassaName: madrassaName ?? this.madrassaName,
    halaqaName: halaqaName ?? this.halaqaName,
    phone: phone ?? this.phone,
    createdAt: createdAt ?? this.createdAt,
  );
}
