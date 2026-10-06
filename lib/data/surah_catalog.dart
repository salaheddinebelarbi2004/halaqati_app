import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import '../models/surah.dart';

/// Single, cached access point to `surah_aya.json`.
///
/// Surah names and ayah counts are display data: they are resolved through
/// this catalog so no screen ever hardcodes them or assumes 114 ayahs.
class SurahCatalog extends ChangeNotifier {
  SurahCatalog._();

  static final SurahCatalog instance = SurahCatalog._();

  static const String assetPath = 'surah_aya.json';

  List<Surah> _surahs = const <Surah>[];
  bool _loaded = false;
  Object? _error;
  Future<void>? _pending;

  bool get isLoaded => _loaded;
  Object? get error => _error;
  List<Surah> get surahs => _surahs;
  int get length => _surahs.length;

  /// Loads the catalog once; safe to call from several widgets at once.
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    _pending ??= _load();
    return _pending!;
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as List<dynamic>;
      _surahs = List<Surah>.unmodifiable(
        decoded.map((dynamic e) => Surah.fromJson(e as Map<String, dynamic>)),
      );
      _loaded = true;
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  Surah? byNumber(int number) {
    for (final s in _surahs) {
      if (s.number == number) return s;
    }
    return null;
  }

  /// Arabic surah name; falls back to the number if the catalog is empty.
  String nameOf(int number) => byNumber(number)?.name ?? 'سورة $number';

  /// Number of ayahs in the given surah (never less than 1).
  int ayahCountOf(int number) {
    final count = byNumber(number)?.numberOfAyahs ?? 0;
    return count < 1 ? 1 : count;
  }

  /// e.g. `البقرة` — name only, for chips and summaries.
  String shortNameOf(int number) => nameOf(number);
}

/// Formats a Qur'anic reference as `سورة البقرة: 2 - 5`.
String formatSurahRange(int surahFrom, int ayahFrom, int surahTo, int ayahTo) {
  final catalog = SurahCatalog.instance;
  if (surahFrom == surahTo) {
    return '${catalog.nameOf(surahFrom)}: $ayahFrom - $ayahTo';
  }
  return '${catalog.nameOf(surahFrom)}: $ayahFrom  ←  ${catalog.nameOf(surahTo)}: $ayahTo';
}

/// Formats a single reference as `البقرة 2:255`.
String formatSurahAyah(int surah, int ayah) =>
    '${SurahCatalog.instance.nameOf(surah)} $surah:$ayah';
