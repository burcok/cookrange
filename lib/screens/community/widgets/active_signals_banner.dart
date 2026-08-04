import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/signal_model.dart';
import '../../../core/services/signal_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Ambient "someone nearby needs something" strip — active [SignalModel]s
/// (gym help / meal share / general) from other users, expiring after their
/// TTL. Purely additive above the feed: collapses to nothing while loading
/// or empty, so it never reserves dead space (unlike a primary surface, this
/// doesn't get its own loading/empty state — it's ambient, not a destination).
class ActiveSignalsBanner extends StatelessWidget {
  const ActiveSignalsBanner({super.key});

  static IconData _iconFor(SignalType type) => switch (type) {
        SignalType.gymHelp => Icons.fitness_center_rounded,
        SignalType.mealShare => Icons.restaurant_rounded,
        SignalType.general => Icons.campaign_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SignalModel>>(
      stream: SignalService().getActiveSignals(),
      builder: (context, snap) {
        final signals = snap.data ?? const <SignalModel>[];
        if (signals.isEmpty) return const SizedBox.shrink();

        final palette = AppPalette.of(context);
        final text = AppText.of(context);
        final l10n = AppLocalizations.of(context);

        return SizedBox(
          height: 72,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: signals.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final signal = signals[i];
              return RepaintBoundary(
                child: _SignalChip(
                  key: ValueKey(signal.id),
                  signal: signal,
                  palette: palette,
                  text: text,
                  ignoreTooltip: l10n.translate('signal.banner.ignore'),
                  onIgnore: () => SignalService().ignoreSignal(signal.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SignalChip extends StatelessWidget {
  final SignalModel signal;
  final AppPalette palette;
  final AppText text;
  final String ignoreTooltip;
  final VoidCallback onIgnore;

  const _SignalChip({
    super.key,
    required this.signal,
    required this.palette,
    required this.text,
    required this.ignoreTooltip,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      radius: AppRadius.lg,
      semanticLabel: '${signal.senderName}: ${signal.message}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInitialsAvatar(
              photoUrl: signal.senderImage,
              name: signal.senderName,
              size: AppSize.avatarSm,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(ActiveSignalsBanner._iconFor(signal.type),
                          size: 12, color: palette.energy),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          signal.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelM.copyWith(
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    signal.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelS.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: ignoreTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: onIgnore,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: palette.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
