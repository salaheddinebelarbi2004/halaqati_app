class Surah {
  final int number;
  final String name;
  final int numberOfAyahs;

  Surah({
    required this.number,
    required this.name,
    required this.numberOfAyahs,
  });

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
    number: json['number'] as int,
    name: json['name'] as String,
    numberOfAyahs: json['numberOfAyahs'] as int,
  );
}
