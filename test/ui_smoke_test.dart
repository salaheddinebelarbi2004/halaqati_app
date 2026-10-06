import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaqati/models/hifd_entry.dart';
import 'package:halaqati/models/student.dart';
import 'package:halaqati/theme/app_spacing.dart';
import 'package:halaqati/theme/app_theme.dart';
import 'package:halaqati/widgets/app_badges.dart';
import 'package:halaqati/widgets/app_button.dart';
import 'package:halaqati/widgets/app_card.dart';
import 'package:halaqati/widgets/app_metrics.dart';
import 'package:halaqati/widgets/app_scaffold.dart';
import 'package:halaqati/widgets/app_states.dart';
import 'package:halaqati/widgets/attendance_tile.dart';
import 'package:halaqati/widgets/date_navigator.dart';
import 'package:halaqati/widgets/hifd_widgets.dart';

/// Window sizes the layout must survive: small phone, large phone, tablet,
/// laptop and a wide desktop window.
const _sizes = <String, Size>{
  'phone': Size(360, 720),
  'phoneLarge': Size(430, 900),
  'tablet': Size(834, 1112),
  'laptop': Size(1280, 800),
  'desktop': Size(1920, 1080),
};

final _student = Student(
  id: '3f9a1c2e-0000-4000-8000-000000000001',
  fullName: 'عبد الله محمد الأحمد',
);

final _entry = HifdEntry(
  studentId: '3f9a1c2e-0000-4000-8000-000000000001',
  date: DateTime(2025, 1, 1),
  type: HifdType.jadid,
  surahFrom: 2,
  ayahFrom: 1,
  surahTo: 2,
  ayahTo: 5,
  grade: 3,
);

Widget _wrap(Widget home, Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    locale: const Locale('ar'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, view) => Directionality(
      textDirection: TextDirection.rtl,
      child: view ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

void _setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _componentGallery() {
  return Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppHeader(title: 'عنوان الصفحة', subtitle: 'وصف مختصر'),
        const AppButton(label: 'إجراء رئيسي', expand: true),
        const SizedBox(height: AppSpacing.sm),
        const AppButton(
          label: 'إجراء ثانوي',
          variant: AppButtonVariant.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatTile(label: 'الحضور', value: '12 / 15'),
              SizedBox(height: AppSpacing.md),
              ProgressCard(
                title: 'نسبة الحضور',
                value: 0.8,
                subtitle: 'هذا الأسبوع',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AttendanceTile(student: _student, status: 'present'),
        const SizedBox(height: AppSpacing.md),
        AttendanceTile(student: _student, status: null, editable: true),
        const SizedBox(height: AppSpacing.md),
        HifdEntryCard(entry: _entry),
        const SizedBox(height: AppSpacing.md),
        HifdProgressCard(studentName: _student.fullName, entries: [_entry]),
        const SizedBox(height: AppSpacing.md),
        HifdTypeSelector(value: HifdType.jadid, onChanged: (String _) {}),
        const SizedBox(height: AppSpacing.md),
        HifdGradeSelector(value: 3, onChanged: (int _) {}),
        const SizedBox(height: AppSpacing.md),
        DateNavigator(date: DateTime(2025, 1, 1), onChanged: (DateTime _) {}),
        const SizedBox(height: AppSpacing.md),
        const StatusSummaryBar(
          items: [
            (label: 'حاضر', count: 3, color: Color(0xFF2E9E6B)),
            (label: 'غائب', count: 1, color: Color(0xFFC0503F)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const EmptyState(
          title: 'لا يوجد بيانات',
          message: 'رسالة توضيحية قصيرة.',
        ),
      ],
    ),
  );
}

void main() {
  group('component library survives every window size and theme', () {
    for (final brightness in Brightness.values) {
      for (final size in _sizes.entries) {
        testWidgets('${size.key} / $brightness', (tester) async {
          _setWindow(tester, size.value);
          await tester.pumpWidget(_wrap(_componentGallery(), brightness));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('AppScaffold keeps content centred and width-constrained', (
    tester,
  ) async {
    _setWindow(tester, const Size(1920, 1080));
    await tester.pumpWidget(
      _wrap(
        const AppScaffold(title: 'عنوان', body: SizedBox.expand()),
        Brightness.light,
      ),
    );

    expect(find.text('عنوان'), findsOneWidget);
    final align = tester.widget<Align>(find.byType(Align).first);
    expect(align.alignment, Alignment.topCenter);
  });

  testWidgets('status labels and grade labels are Arabic', (tester) async {
    _setWindow(tester, const Size(420, 900));
    await tester.pumpWidget(
      _wrap(
        AttendanceTile(student: _student, status: 'excused'),
        Brightness.light,
      ),
    );
    expect(find.text('بعذر'), findsOneWidget);
  });

  // Regression: LinearProgressIndicator forces minWidth: double.infinity, so
  // an AppProgressBar dropped straight into a Row used to make the row
  // infinitely wide. The Expanded name then got a NaN width and vanished,
  // leaving the percentage floating on its own ("100% without a name"), and
  // in the hifd overview the card stretched into a long empty strip.
  group('AppProgressBar inside a Row stays bounded', () {
    for (final size in _sizes.entries) {
      testWidgets(size.key, (tester) async {
        _setWindow(tester, size.value);
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: const [
                    Expanded(child: Text('عبد الله محمد')),
                    SizedBox(width: AppSpacing.sm),
                    AppProgressBar(
                      value: 1,
                      showLabel: false,
                      color: Color(0xFFB4894A),
                    ),
                  ],
                ),
              ),
            ),
            Brightness.light,
          ),
        );

        expect(tester.takeException(), isNull);

        final card = tester.getSize(
          find
              .ancestor(
                of: find.text('عبد الله محمد'),
                matching: find.byType(Row),
              )
              .first,
        );
        expect(card.width, lessThanOrEqualTo(size.value.width));

        // The name must still occupy real space next to the bar.
        final name = tester.getSize(find.text('عبد الله محمد'));
        expect(name.width, greaterThan(40));
      });
    }
  });
}
