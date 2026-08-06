/// Recursively merges [maps] left-to-right — a later map's LEAF values win,
/// but a later map's nested Map only overrides the keys it actually
/// specifies, never wholesale-replacing a sibling subtree an earlier map
/// contributed.
///
/// Used by [AppConfigService] to merge `app_config/global` +
/// `app_config/client` + `app_config/critical`. A plain `{...a, ...b}`
/// spread is NOT sufficient there: three schema groups are genuinely split
/// across more than one document (`ai`: client+server; `gamification`:
/// client+server; `client`: client+critical — see
/// `functions/config_schema.json`'s per-key `doc` assignment), so a shallow
/// merge would let a later, partial `ai` map silently discard every
/// `ai.*` sub-field an earlier map had that the later one doesn't mention.
/// Mirrors `functions/app_config.js`'s identical `deepMerge` exactly — the
/// two must agree, since both merge the SAME three Firestore documents.
Map<String, dynamic> deepMergeMaps(List<Map<String, dynamic>> maps) {
  final result = <String, dynamic>{};
  for (final map in maps) {
    for (final entry in map.entries) {
      final existing = result[entry.key];
      final incoming = entry.value;
      if (existing is Map && incoming is Map) {
        result[entry.key] = deepMergeMaps([_asStringMap(existing), _asStringMap(incoming)]);
      } else {
        result[entry.key] = incoming;
      }
    }
  }
  return result;
}

Map<String, dynamic> _asStringMap(Map v) =>
    v.map((k, val) => MapEntry('$k', val));
