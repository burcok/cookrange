import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Flattens a nested JSON map into dot-separated keys.
Map<String, dynamic> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final result = <String, dynamic>{};
  for (final entry in json.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      result.addAll(_flatten(value, key));
    } else {
      result[key] = value;
    }
  }
  return result;
}

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> tr;

  setUpAll(() {
    final enRaw = File('assets/localization/en.json').readAsStringSync();
    final trRaw = File('assets/localization/tr.json').readAsStringSync();
    en = _flatten(json.decode(enRaw) as Map<String, dynamic>);
    tr = _flatten(json.decode(trRaw) as Map<String, dynamic>);
  });

  test('en.json and tr.json have the same key set', () {
    final enKeys = en.keys.toSet();
    final trKeys = tr.keys.toSet();

    final missingInTr = enKeys.difference(trKeys);
    final missingInEn = trKeys.difference(enKeys);

    if (missingInTr.isNotEmpty) {
      final sorted = missingInTr.toList()..sort();
      fail('Keys present in en.json but MISSING in tr.json (${sorted.length}):\n'
          '${sorted.map((k) => '  $k').join('\n')}');
    }

    if (missingInEn.isNotEmpty) {
      final sorted = missingInEn.toList()..sort();
      fail('Keys present in tr.json but MISSING in en.json (${sorted.length}):\n'
          '${sorted.map((k) => '  $k').join('\n')}');
    }
  });

  test('No localization value is an empty string', () {
    final emptyEn = en.entries.where((e) => e.value == '').map((e) => e.key).toList()..sort();
    final emptyTr = tr.entries.where((e) => e.value == '').map((e) => e.key).toList()..sort();

    final allEmpty = {...emptyEn, ...emptyTr}.toList()..sort();
    if (allEmpty.isNotEmpty) {
      fail('Empty string values found in localization files:\n'
          '${allEmpty.map((k) => '  $k').join('\n')}');
    }
  });
}
