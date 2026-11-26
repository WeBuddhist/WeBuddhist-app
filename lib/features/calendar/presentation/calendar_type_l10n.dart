import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';

/// Display name of a calendar type code from `GET /calendar/types`. A code the
/// app has no string for yet shows capitalized rather than not at all.
String calendarTypeLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'phugpa' => l10n.calendar_type_phugpa,
    'tsurphu' => l10n.calendar_type_tsurphu,
    'nyingmapa' => l10n.calendar_type_nyingmapa,
    'sinhalese' => l10n.calendar_type_sinhalese,
    'thai' => l10n.calendar_type_thai,
    'burmese' => l10n.calendar_type_burmese,
    'lao' => l10n.calendar_type_lao,
    'chinese' => l10n.calendar_type_chinese,
    'vietnamese' => l10n.calendar_type_vietnamese,
    'korean' => l10n.calendar_type_korean,
    'japanese' => l10n.calendar_type_japanese,
    _ => _capitalize(code),
  };
}

/// Display name of a calendar tradition code from `GET /calendar/types`.
String calendarTraditionLabel(AppLocalizations l10n, String code) {
  return switch (code) {
    'vajrayana' => l10n.calendar_tradition_vajrayana,
    'theravada' => l10n.calendar_tradition_theravada,
    'mahayana' => l10n.calendar_tradition_mahayana,
    _ => _capitalize(code),
  };
}

String _capitalize(String code) =>
    code.isEmpty ? code : '${code[0].toUpperCase()}${code.substring(1)}';
