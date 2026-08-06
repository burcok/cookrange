#!/usr/bin/env node
/**
 * Cookrange config schema codegen.
 *
 * Reads the ONE canonical, hand-edited source of truth —
 * functions/config_schema.json — and generates:
 *
 *   lib/core/config/app_config_defaults.g.dart
 *     const, dotted-key defaults for every admin-editable setting. Const-ness
 *     is load-bearing: it gives a cold app start correct per-key values with
 *     zero I/O, which is how the fail-open feature-flag bug (see
 *     DECISIONS.md ADR-023) gets fixed at the root rather than patched at
 *     each call site.
 *
 *   lib/core/config/app_config_schema.g.dart
 *     A const list of field descriptors (key/type/doc/group/label/description/
 *     impact/sensitive/min/max/enum) — drives the schema-generated admin
 *     config editor and the read-side bounds clamp. Carries no `default`
 *     (that's the file above); the two are deliberately separate concerns.
 *
 * There is NO codegen step for the JS (Cloud Functions) side — functions/
 * app_config.js just `require()`s config_schema.json directly at module load.
 * JavaScript has no compile-time type checking to preserve, so codegen would
 * add a build step to the deploy path for zero safety benefit. Dart gets
 * codegen because Dart's static typing IS the reason to prefer Dart for the
 * ~120 settings this schema covers; throwing that away for a runtime map
 * lookup (a typo'd key compiles fine, fails at runtime) would be a real
 * regression. See DECISIONS.md ADR-023.
 *
 *   scripts/generated/config-schema.ts
 *     A TS mirror of app_config_schema.g.dart — same fields (key/type/doc/
 *     group/label/description/impact/sensitive/min/max/enumValues), no
 *     `default` on ConfigField itself (same deliberate split as the Dart pair
 *     above) — instead a SEPARATE `configDefaults: Record<string, unknown>`
 *     export mirrors kConfigDefaults, so the admin panel can show "current
 *     value" against "default value" without re-deriving it. `doc` is a
 *     plain string union (`'critical' | 'client' | 'server'`) rather than an
 *     enum with a parse helper — TS doesn't need Dart's runtime string→enum
 *     conversion since the literal type already covers the value. `type` is
 *     likewise the literal union `ConfigFieldType` (all 11 values actually
 *     used across the schema), not a bare `string` — this is what lets a
 *     `switch (field.type)` in the panel's form-widget dispatch get real
 *     exhaustiveness checking from `tsc` when an 12th type is ever added.
 *     Consumed by cookrange-admin (the web admin panel, DECISIONS.md
 *     ADR-024): copy this file to cookrange-admin/src/lib/config-schema.ts
 *     after regenerating. No shared npm package between the two repos for M1
 *     — see ADR-024.
 *
 * Usage:
 *   node scripts/gen_config_schema.js
 *   cp scripts/generated/config-schema.ts ../cookrange-admin/src/lib/config-schema.ts
 *
 * CI freshness check (two separate steps, not a bespoke --check flag):
 *   node scripts/gen_config_schema.js
 *   git diff --exit-code lib/core/config/app_config_defaults.g.dart lib/core/config/app_config_schema.g.dart scripts/generated/config-schema.ts
 */

'use strict';

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const SCHEMA_PATH = path.join(REPO_ROOT, 'functions', 'config_schema.json');
const DEFAULTS_OUT = path.join(REPO_ROOT, 'lib', 'core', 'config', 'app_config_defaults.g.dart');
const SCHEMA_OUT = path.join(REPO_ROOT, 'lib', 'core', 'config', 'app_config_schema.g.dart');
const TS_SCHEMA_OUT = path.join(REPO_ROOT, 'scripts', 'generated', 'config-schema.ts');

const GENERATED_BANNER = (sourceFile) => `// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Source of truth: ${sourceFile}
// Regenerate:       node scripts/gen_config_schema.js
//
// Any change to a setting's default, bounds, or metadata belongs in
// ${sourceFile}, never in this file directly — a hand-edit here will be
// silently overwritten by the next regeneration. Neither this repo's CI nor
// cookrange-admin's checks this automatically today; cookrange-admin has a
// local, manually-run freshness check (\`npm run verify:config-schema\`) --
// see that repo's e2e/README.md for why it isn't wired into CI yet.
`;

// ── Dart literal rendering ──────────────────────────────────────────────────

/** Escapes a string for a Dart single-quoted string literal. */
function dartString(s) {
  const escaped = String(s)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\n/g, '\\n')
    .replace(/\$/g, '\\$');
  return `'${escaped}'`;
}

/**
 * Renders a nested (non-top-level) JSON value as a Dart literal, inferring
 * int vs. double from the JSON value's own shape (Number.isInteger).
 *
 * DELIBERATE DECISION: every nested map/object field (xp_table's per-kind
 * records, cost.pricing's mixed int/double table, the rate-limit objects,
 * gym_commission_try, etc.) is emitted as `Map<String, dynamic>`, never a
 * strictly-typed `Map<String, double>` — because a single schema-level type
 * annotation like "map<string,double>" cannot resolve, for an individual
 * JSON number that happens to be whole (e.g. gym_commission_try.yearly: 120),
 * whether the AUTHOR meant int or double, and guessing wrong would produce a
 * Dart Map literal that fails to compile under a strict element type. Using
 * `dynamic` sidesteps the ambiguity entirely and matches the existing
 * lenient-coercion architecture already in app_config_model.dart (the _int/
 * _dbl helpers there exist precisely because Firestore-sourced numeric data
 * has this same wire-level ambiguity). Top-level SCALAR fields (a plain
 * "double" setting, not a map of them) are NOT subject to this — see
 * renderTopLevelValue below, which honors the declared type exactly.
 */
function renderNestedValue(value) {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') {
    return Number.isInteger(value) ? String(value) : String(value);
  }
  if (typeof value === 'string') return dartString(value);
  if (Array.isArray(value)) {
    return `<dynamic>[${value.map(renderNestedValue).join(', ')}]`;
  }
  if (typeof value === 'object') {
    const entries = Object.entries(value)
      .map(([k, v]) => `${dartString(k)}: ${renderNestedValue(v)}`)
      .join(', ');
    return `<String, dynamic>{${entries}}`;
  }
  throw new Error(`Cannot render nested value: ${JSON.stringify(value)}`);
}

/**
 * Renders a TOP-LEVEL schema entry's default as a typed Dart literal,
 * honoring the entry's declared `type` exactly (unlike renderNestedValue,
 * which infers from JSON shape). This is what makes `economy.
 * referral_commission_try`'s default of `5` in JSON correctly emit as the
 * Dart double literal `5.0`, not the int literal `5`.
 */
function renderTopLevelValue(entry, key) {
  const { type, default: def } = entry;
  switch (type) {
    case 'bool':
      if (typeof def !== 'boolean') throw new Error(`${key}: default must be bool, got ${JSON.stringify(def)}`);
      return def ? 'true' : 'false';
    case 'int':
      if (typeof def !== 'number' || !Number.isInteger(def)) {
        throw new Error(`${key}: type is "int" but default is not an integer: ${JSON.stringify(def)}`);
      }
      return String(def);
    case 'double':
      if (typeof def !== 'number') throw new Error(`${key}: type is "double" but default is not a number: ${JSON.stringify(def)}`);
      // Force a decimal point so Dart parses it as a double literal even
      // when the JSON value is a whole number (e.g. 120 -> 120.0).
      return Number.isInteger(def) ? `${def}.0` : String(def);
    case 'string':
    case 'enum':
      if (typeof def !== 'string') throw new Error(`${key}: type is "${type}" but default is not a string: ${JSON.stringify(def)}`);
      return dartString(def);
    case 'string_list':
      if (!Array.isArray(def)) throw new Error(`${key}: type is "string_list" but default is not an array: ${JSON.stringify(def)}`);
      return `<String>[${def.map(dartString).join(', ')}]`;
    case 'map<string,double>': {
      // A flat, single-level map with a DECLARED leaf type — unlike the
      // generic object/map<string,object> case below, every value here is
      // known to be conceptually a double, so a whole-number JSON value
      // (economy.gym_commission_try.yearly: 120) must still render as the
      // Dart double literal 120.0, not the int literal 120. Left to
      // renderNestedValue's shape-inference alone, a whole-number double
      // would render as an int — harmless only because the container type
      // is `dynamic` and every existing reader goes through app_config_
      // model.dart's lenient `_dbl()` coercer, but a future consumer doing
      // a bare `as double` cast on an un-coerced value would crash on it.
      // Forcing the literal here removes that latent footgun instead of
      // relying on every future call site remembering to coerce.
      if (def === null || typeof def !== 'object' || Array.isArray(def)) {
        throw new Error(`${key}: type is "map<string,double>" but default is not an object: ${JSON.stringify(def)}`);
      }
      const entries = Object.entries(def).map(([k, v]) => {
        if (typeof v !== 'number') throw new Error(`${key}.${k}: expected a number, got ${JSON.stringify(v)}`);
        return `${dartString(k)}: ${Number.isInteger(v) ? `${v}.0` : String(v)}`;
      });
      return `<String, double>{${entries.join(', ')}}`;
    }
    case 'map<string,int>': {
      // Symmetric with map<string,double> above: a declared, uniform leaf
      // type, so render as a strictly-typed Map<String, int> rather than
      // falling through to the dynamic-shape path.
      if (def === null || typeof def !== 'object' || Array.isArray(def)) {
        throw new Error(`${key}: type is "map<string,int>" but default is not an object: ${JSON.stringify(def)}`);
      }
      const entries = Object.entries(def).map(([k, v]) => {
        if (typeof v !== 'number' || !Number.isInteger(v)) throw new Error(`${key}.${k}: expected an integer, got ${JSON.stringify(v)}`);
        return `${dartString(k)}: ${v}`;
      });
      return `<String, int>{${entries.join(', ')}}`;
    }
    default:
      // Remaining map<...>/object types (map<string,string>, map<string,object>,
      // plain "object") have genuinely heterogeneous or per-key-record shapes
      // (xp_table's {points, dailyCap} records, cost.pricing's mixed int/double
      // table, the rate-limit {windowMs,max,lockMs} objects) where forcing a
      // single uniform leaf type makes no sense — see renderNestedValue's own
      // doc comment for why these fall back to Map<String, dynamic> with
      // shape-inferred leaves instead.
      if (type.startsWith('map<') || type === 'object') {
        if (def === null || typeof def !== 'object' || Array.isArray(def)) {
          throw new Error(`${key}: type is "${type}" but default is not an object: ${JSON.stringify(def)}`);
        }
        return renderNestedValue(def);
      }
      throw new Error(`${key}: unknown schema type "${type}"`);
  }
}

// ── TS literal rendering ────────────────────────────────────────────────────

/** Escapes a string for a TS single-quoted string literal. */
function tsString(s) {
  return `'${String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, '\\n')}'`;
}

/**
 * Renders any JSON value (default value or nested map/object entry) as a TS
 * literal. Unlike the Dart side, TS has no int/double distinction to infer,
 * so this is one function for every shape instead of Dart's top-level/nested
 * split — a plain JS number already prints the same whether it's a top-level
 * `economy.referral_commission_try: 5` or a nested `cost.pricing` field.
 * Object keys are always quoted (not just when they aren't valid bare
 * identifiers) since some are store product IDs like
 * 'com.cookrange.premium.monthly' that aren't valid identifiers anyway —
 * one rule, not a per-key identifier check.
 */
function renderTsValue(value) {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string') return tsString(value);
  if (Array.isArray(value)) return `[${value.map(renderTsValue).join(', ')}]`;
  if (typeof value === 'object') {
    const entries = Object.entries(value).map(([k, v]) => `${tsString(k)}: ${renderTsValue(v)}`);
    return `{ ${entries.join(', ')} }`;
  }
  throw new Error(`Cannot render TS value: ${JSON.stringify(value)}`);
}

// ── Load + validate ─────────────────────────────────────────────────────────

function loadSchema() {
  const raw = fs.readFileSync(SCHEMA_PATH, 'utf8');
  const schema = JSON.parse(raw);
  const entries = [];
  for (const [key, entry] of Object.entries(schema)) {
    if (key === '_meta') continue;
    for (const required of ['type', 'doc', 'group', 'label', 'description', 'impact']) {
      if (entry[required] === undefined) {
        throw new Error(`${key}: missing required field "${required}"`);
      }
    }
    if (typeof entry.description !== 'string' || entry.description.trim().length < 10) {
      throw new Error(`${key}: "description" must be a real sentence (>=10 chars), not a placeholder`);
    }
    if (typeof entry.impact !== 'string' || entry.impact.trim().length < 5) {
      throw new Error(`${key}: "impact" must be a real sentence (>=5 chars), not a placeholder`);
    }
    if (!['critical', 'client', 'server'].includes(entry.doc)) {
      throw new Error(`${key}: invalid doc "${entry.doc}" (must be critical|client|server)`);
    }
    if (!Object.prototype.hasOwnProperty.call(entry, 'default')) {
      throw new Error(`${key}: missing "default"`);
    }
    entries.push({ key, ...entry });
  }
  entries.sort((a, b) => a.key.localeCompare(b.key));
  return entries;
}

// ── Generators ───────────────────────────────────────────────────────────────

function generateDefaultsDart(entries) {
  const lines = [];
  lines.push(GENERATED_BANNER('functions/config_schema.json'));
  lines.push('library;');
  lines.push('');
  lines.push('/// Dotted-key defaults for every admin-editable setting, keyed exactly as');
  lines.push('/// they appear in `functions/config_schema.json` and in the `app_config/*`');
  lines.push('/// Firestore documents. `const` so a cold start has correct values (incl.');
  lines.push('/// every feature kill-switch) with zero I/O — see DECISIONS.md ADR-023.');
  lines.push('const Map<String, dynamic> kConfigDefaults = {');
  for (const entry of entries) {
    lines.push(`  ${dartString(entry.key)}: ${renderTopLevelValue(entry, entry.key)},`);
  }
  lines.push('};');
  lines.push('');
  return lines.join('\n');
}

function generateSchemaDart(entries) {
  const lines = [];
  lines.push(GENERATED_BANNER('functions/config_schema.json'));
  lines.push('library;');
  lines.push('');
  lines.push('/// Which `app_config/{doc}` a setting is read from — see DECISIONS.md ADR-023');
  lines.push('/// (placement rule: a setting lives in the most restrictive doc that still');
  lines.push('/// contains every one of its readers).');
  lines.push('enum ConfigDoc { critical, client, server }');
  lines.push('');
  lines.push('ConfigDoc configDocFromString(String s) => switch (s) {');
  lines.push("  'critical' => ConfigDoc.critical,");
  lines.push("  'client' => ConfigDoc.client,");
  lines.push("  'server' => ConfigDoc.server,");
  lines.push("  _ => throw ArgumentError('Unknown ConfigDoc: \$s'),");
  lines.push('};');
  lines.push('');
  lines.push('/// One schema-declared field descriptor. Drives the schema-generated admin');
  lines.push('/// config editor (Faz C) and the read-side bounds clamp (DECISIONS.md ADR-023).');
  lines.push('/// Carries no `default` — see kConfigDefaults in app_config_defaults.g.dart.');
  lines.push('class ConfigField {');
  lines.push('  final String key;');
  lines.push('  final String type;');
  lines.push('  final ConfigDoc doc;');
  lines.push('  final String group;');
  lines.push('  final String label;');
  lines.push('  final String description;');
  lines.push('  final String impact;');
  lines.push('  final bool sensitive;');
  lines.push('  final num? min;');
  lines.push('  final num? max;');
  lines.push('  final List<String>? enumValues;');
  lines.push('');
  lines.push('  const ConfigField({');
  lines.push('    required this.key,');
  lines.push('    required this.type,');
  lines.push('    required this.doc,');
  lines.push('    required this.group,');
  lines.push('    required this.label,');
  lines.push('    required this.description,');
  lines.push('    required this.impact,');
  lines.push('    this.sensitive = false,');
  lines.push('    this.min,');
  lines.push('    this.max,');
  lines.push('    this.enumValues,');
  lines.push('  });');
  lines.push('}');
  lines.push('');
  lines.push('const List<ConfigField> kConfigSchema = [');
  for (const entry of entries) {
    const parts = [
      `key: ${dartString(entry.key)}`,
      `type: ${dartString(entry.type)}`,
      `doc: ConfigDoc.${entry.doc}`,
      `group: ${dartString(entry.group)}`,
      `label: ${dartString(entry.label)}`,
      `description: ${dartString(entry.description)}`,
      `impact: ${dartString(entry.impact)}`,
    ];
    if (entry.sensitive) parts.push('sensitive: true');
    if (entry.min !== undefined) parts.push(`min: ${entry.min}`);
    if (entry.max !== undefined) parts.push(`max: ${entry.max}`);
    if (entry.enum !== undefined) {
      parts.push(`enumValues: <String>[${entry.enum.map(dartString).join(', ')}]`);
    }
    lines.push(`  ConfigField(${parts.join(', ')}),`);
  }
  lines.push('];');
  lines.push('');
  return lines.join('\n');
}

function generateSchemaTs(entries) {
  // All 11 `type` values actually used across the schema today, derived from
  // the real data rather than hand-maintained separately — if a 12th type is
  // ever added to config_schema.json, this list (and therefore every
  // exhaustive `switch (field.type)` the panel writes against it) updates on
  // the next regeneration instead of silently missing it.
  const typeValues = [...new Set(entries.map((e) => e.type))].sort();

  const lines = [];
  lines.push(GENERATED_BANNER('functions/config_schema.json'));
  lines.push("export type ConfigDoc = 'critical' | 'client' | 'server';");
  lines.push('');
  lines.push('// Every `type` value used across the schema today — see this generator\'s');
  lines.push('// own header comment for why this is a literal union, not `string`.');
  lines.push(`export type ConfigFieldType = ${typeValues.map(tsString).join(' | ')};`);
  lines.push('');
  lines.push('// Which `app_config/{doc}` a setting is read from — see DECISIONS.md ADR-023');
  lines.push('// (placement rule: a setting lives in the most restrictive doc that still');
  lines.push('// contains every one of its readers).');
  lines.push('export interface ConfigField {');
  lines.push('  key: string;');
  lines.push('  type: ConfigFieldType;');
  lines.push('  doc: ConfigDoc;');
  lines.push('  group: string;');
  lines.push('  label: string;');
  lines.push('  // Admin-facing (Turkish): what this setting controls and what changing it');
  lines.push('  // does, written for someone reading the panel, not the code. Distinct from');
  lines.push('  // config_schema.json\'s own `note` field, which stays developer-facing.');
  lines.push('  description: string;');
  lines.push('  // Admin-facing (Turkish), one line: the concrete risk of changing this.');
  lines.push('  impact: string;');
  lines.push('  sensitive: boolean;');
  lines.push('  min?: number;');
  lines.push('  max?: number;');
  lines.push('  enumValues?: string[];');
  lines.push('}');
  lines.push('');
  lines.push('// One schema-declared field descriptor per admin-editable setting — drives');
  lines.push('// the config editor\'s form generation and validation (DECISIONS.md ADR-023).');
  lines.push('// Carries no `default` — see configDefaults below, same deliberate split as');
  lines.push('// kConfigDefaults/kConfigSchema in the Dart counterpart of this file.');
  lines.push('export const configSchema: ConfigField[] = [');
  for (const entry of entries) {
    const parts = [
      `key: ${tsString(entry.key)}`,
      `type: ${tsString(entry.type)}`,
      `doc: ${tsString(entry.doc)}`,
      `group: ${tsString(entry.group)}`,
      `label: ${tsString(entry.label)}`,
      `description: ${tsString(entry.description)}`,
      `impact: ${tsString(entry.impact)}`,
      `sensitive: ${entry.sensitive ? 'true' : 'false'}`,
    ];
    if (entry.min !== undefined) parts.push(`min: ${entry.min}`);
    if (entry.max !== undefined) parts.push(`max: ${entry.max}`);
    if (entry.enum !== undefined) {
      parts.push(`enumValues: [${entry.enum.map(tsString).join(', ')}]`);
    }
    lines.push(`  { ${parts.join(', ')} },`);
  }
  lines.push('];');
  lines.push('');
  lines.push('// Dotted-key defaults for every setting, keyed exactly as configSchema above');
  lines.push('// and as the Firestore `app_config/*` documents themselves — the TS mirror of');
  lines.push('// kConfigDefaults (app_config_defaults.g.dart). This is what makes a "reset to');
  lines.push('// default" control and a "differs from default" badge in the config editor');
  lines.push('// possible at all; before this export, the panel had no way to know what a');
  lines.push('// setting\'s default even was. `unknown`, not a per-key union, since the shapes');
  lines.push('// genuinely vary (bool/number/string/array/nested object per entry) — callers');
  lines.push('// narrow using the matching configSchema entry\'s `type`.');
  lines.push('export const configDefaults: Record<string, unknown> = {');
  for (const entry of entries) {
    lines.push(`  ${tsString(entry.key)}: ${renderTsValue(entry.default)},`);
  }
  lines.push('};');
  lines.push('');
  return lines.join('\n');
}

// ── Main ─────────────────────────────────────────────────────────────────────

function main() {
  const entries = loadSchema();
  fs.mkdirSync(path.dirname(DEFAULTS_OUT), { recursive: true });
  fs.mkdirSync(path.dirname(TS_SCHEMA_OUT), { recursive: true });
  fs.writeFileSync(DEFAULTS_OUT, generateDefaultsDart(entries), 'utf8');
  fs.writeFileSync(SCHEMA_OUT, generateSchemaDart(entries), 'utf8');
  fs.writeFileSync(TS_SCHEMA_OUT, generateSchemaTs(entries), 'utf8');
  console.log(`Generated ${entries.length} config field(s):`);
  console.log(`  ${path.relative(REPO_ROOT, DEFAULTS_OUT)}`);
  console.log(`  ${path.relative(REPO_ROOT, SCHEMA_OUT)}`);
  console.log(`  ${path.relative(REPO_ROOT, TS_SCHEMA_OUT)}`);
}

main();
