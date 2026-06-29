import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/ds/ds.dart';

/// The legal documents Cookrange ships. Each maps to a pair of markdown assets
/// under `assets/legal/<base>_<lang>.md` (en/tr), rendered by [_MarkdownView].
enum LegalDocumentType { privacyPolicy, termsOfUse, kvkkClarification, explicitConsent }

extension LegalDocumentTypeX on LegalDocumentType {
  String get assetBase => switch (this) {
        LegalDocumentType.privacyPolicy => 'privacy_policy',
        LegalDocumentType.termsOfUse => 'terms_of_use',
        LegalDocumentType.kvkkClarification => 'kvkk_aydinlatma',
        LegalDocumentType.explicitConsent => 'explicit_consent',
      };

  String titleKey() => switch (this) {
        LegalDocumentType.privacyPolicy => 'legal.privacy_title',
        LegalDocumentType.termsOfUse => 'legal.terms_title',
        LegalDocumentType.kvkkClarification => 'legal.kvkk_title',
        LegalDocumentType.explicitConsent => 'legal.consent_title',
      };
}

/// Renders a long-form legal document from a localized markdown asset.
///
/// Legal text lives in `assets/legal/` (not in the i18n JSON) so the documents
/// can be comprehensive without bloating localization or the parity test.
class LegalScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalScreen({super.key, required this.type});

  Future<String> _load(String langCode) async {
    final lang = langCode == 'tr' ? 'tr' : 'en';
    final path = 'assets/legal/${type.assetBase}_$lang.md';
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      // Fallback to English if the localized file is missing.
      return rootBundle.loadString('assets/legal/${type.assetBase}_en.md');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate(type.titleKey()),
            style: AppText.of(context).titleL),
      ),
      body: FutureBuilder<String>(
        future: _load(lang),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AppSkeletonList(itemCount: 8),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return AppErrorState(
              title: l10n.translate('legal.load_error'),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 40.h),
            child: _MarkdownView(source: snap.data!),
          );
        },
      ),
    );
  }
}

/// Lightweight, dependency-free markdown renderer tuned for legal documents.
/// Supports: # / ## / ### headings, - bullets, | tables |, --- rules,
/// *italic notes*, **bold** inline spans, and paragraphs.
class _MarkdownView extends StatelessWidget {
  final String source;
  const _MarkdownView({required this.source});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    final tableBuffer = <String>[];
    void flushTable() {
      if (tableBuffer.isEmpty) return;
      widgets.add(_buildTable(context, List.of(tableBuffer)));
      widgets.add(SizedBox(height: 12.h));
      tableBuffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      // Table rows accumulate until a non-table line.
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        tableBuffer.add(trimmed);
        continue;
      } else if (tableBuffer.isNotEmpty) {
        flushTable();
      }

      if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: 10.h));
      } else if (trimmed == '---') {
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Divider(color: palette.border, height: 1),
        ));
      } else if (trimmed.startsWith('### ')) {
        widgets.add(_heading(context, trimmed.substring(4),
            t.titleM.copyWith(fontWeight: FontWeight.w700), 16.h));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(_heading(context, trimmed.substring(3),
            t.titleL.copyWith(fontWeight: FontWeight.w800), 18.h));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(_heading(context, trimmed.substring(2),
            t.headlineS.copyWith(fontWeight: FontWeight.w800), 8.h));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(_bullet(context, trimmed.substring(2)));
      } else if (trimmed.startsWith('*') &&
          trimmed.endsWith('*') &&
          !trimmed.startsWith('**')) {
        // Italic note line.
        widgets.add(Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: Text(
            trimmed.replaceAll('*', ''),
            style: t.labelS.copyWith(
                color: palette.textTertiary, fontStyle: FontStyle.italic),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: RichText(
            text: _inlineSpans(context, trimmed,
                t.bodyM.copyWith(color: palette.textSecondary, height: 1.6)),
          ),
        ));
      }
    }
    flushTable();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _heading(
      BuildContext context, String text, TextStyle style, double topGap) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 6.h),
      child: Text(text,
          style: style.copyWith(color: AppPalette.of(context).textPrimary)),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 7.h, right: 8.w),
            child: Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                  color: palette.textTertiary, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: RichText(
              text: _inlineSpans(context, text,
                  t.bodyM.copyWith(color: palette.textSecondary, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<String> rows) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);

    List<String> cells(String row) {
      final parts = row.split('|');
      // Drop the empty leading/trailing segments from the outer pipes.
      if (parts.isNotEmpty && parts.first.trim().isEmpty) parts.removeAt(0);
      if (parts.isNotEmpty && parts.last.trim().isEmpty) {
        parts.removeLast();
      }
      return parts.map((c) => c.trim()).toList();
    }

    // Skip the |---|---| separator rows.
    final dataRows = rows
        .where((r) => !RegExp(r'^\|[\s:\-|]+\|$').hasMatch(r))
        .map(cells)
        .where((c) => c.isNotEmpty)
        .toList();
    if (dataRows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 6.h),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: Column(
        children: [
          for (var i = 0; i < dataRows.length; i++)
            Container(
              decoration: BoxDecoration(
                color: i == 0
                    ? palette.surfaceVariant
                    : Colors.transparent,
                border: i == dataRows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(color: palette.border, width: 0.5)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < dataRows[i].length; j++)
                    Expanded(
                      flex: j == 0 ? 5 : 4,
                      child: Padding(
                        padding: EdgeInsets.only(right: j == 0 ? 8.w : 0),
                        child: RichText(
                          text: _inlineSpans(
                            context,
                            dataRows[i][j],
                            (i == 0 ? t.labelM : t.bodyM).copyWith(
                              color: i == 0
                                  ? palette.textPrimary
                                  : palette.textSecondary,
                              fontWeight:
                                  i == 0 ? FontWeight.w700 : FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Parses **bold** spans within a line into a TextSpan tree.
  TextSpan _inlineSpans(BuildContext context, String text, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: base.copyWith(
            fontWeight: FontWeight.w700,
            color: AppPalette.of(context).textPrimary),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
