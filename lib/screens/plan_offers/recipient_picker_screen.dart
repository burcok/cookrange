import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_client_model.dart';
import '../../core/models/gym_member_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/gym_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../meal_plan_templates/template_library_screen.dart';
import 'compose_offer_screen.dart';

/// A minimal, source-agnostic recipient — adapted from whichever list this
/// screen is backing (`GymMemberModel` or `CoachClientModel`), so the picker
/// UI below doesn't need to know which.
class _Recipient {
  final String uid;
  final String? displayName;
  final String? photoURL;
  const _Recipient({required this.uid, this.displayName, this.photoURL});
}

/// Faz 3 §3.5 — step 1 of the send flow: "üye seç (tek veya çoklu)". Reuses
/// the EXISTING member/client data layer (`GymService.getMembersStream` /
/// `CoachService.getClientsStream` — the same streams `gym_members_screen
/// .dart`/`coach_clients_screen.dart` already use) rather than a new query;
/// only the presentation is new, because neither existing screen has a
/// selection mode — one is a management list (swipe-to-remove), the other
/// mixes pending-request actions with an active-client list, and retrofitting
/// either with multi-select would risk their own, already-verified behavior
/// for a purpose neither was built for.
///
/// Coach recipients are filtered to `CoachClientStatus.active` — matching
/// `sendPlanOffer`'s own `isEligibleRecipient` check (functions/templates.js)
/// exactly, so nobody can select someone the callable would reject anyway.
class PlanOfferRecipientPickerScreen extends StatefulWidget {
  /// 'gym' | 'coach'.
  final String authorType;
  final String? gymId;

  const PlanOfferRecipientPickerScreen({
    super.key,
    required this.authorType,
    this.gymId,
  });

  @override
  State<PlanOfferRecipientPickerScreen> createState() =>
      _PlanOfferRecipientPickerScreenState();
}

class _PlanOfferRecipientPickerScreenState
    extends State<PlanOfferRecipientPickerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _selectedUids = {};
  final Map<String, _Recipient> _byUid = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Recipient> _filter(List<_Recipient> all) {
    for (final r in all) {
      _byUid[r.uid] = r;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((r) => (r.displayName ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  Future<void> _next() async {
    final selected = _selectedUids.toList();
    if (selected.isEmpty) return;
    final names = {
      for (final uid in selected) uid: _byUid[uid]?.displayName ?? '',
    };

    await Navigator.of(context).push(AppTransitions.slideUp(
      MealPlanTemplateLibraryScreen(
        authorType: widget.authorType,
        gymId: widget.gymId,
        onPick: (tpl) {
          // Pop the (picker-mode) library screen itself before pushing the
          // composer, so "back" from compose returns to recipient selection,
          // not to a now-irrelevant template list.
          Navigator.of(context).pop();
          Navigator.of(context).push(AppTransitions.slideUp(
            PlanOfferComposeScreen(
              template: tpl,
              recipientUids: selected,
              recipientNames: names,
            ),
          ));
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(l10n.translate('plan_offer.picker.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, 0),
            child: AppTextField(
              controller: _searchCtrl,
              hintText: l10n.translate('plan_offer.picker.search_hint'),
              prefixIcon:
                  Icon(Icons.search_rounded, color: palette.textSecondary),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Expanded(
            child: widget.authorType == 'gym'
                ? _buildGymList(context)
                : _buildCoachList(context),
          ),
          _buildBottomBar(context, l10n),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations l10n) {
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.sm.h, AppSpacing.lg.w, AppSpacing.lg.h),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          label: _selectedUids.isEmpty
              ? l10n.translate('plan_offer.picker.next_disabled')
              : l10n.translate('plan_offer.picker.next',
                  variables: {'n': '${_selectedUids.length}'}),
          onPressed: _selectedUids.isEmpty ? null : _next,
        ),
      ),
    );
  }

  Widget _buildGymList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gymId = widget.gymId;
    if (gymId == null || gymId.isEmpty) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n.translate('plan_offer.picker.empty_title'),
      );
    }
    return StreamBuilder<List<GymMemberModel>>(
      stream: GymService().getMembersStream(gymId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppSkeletonList(itemCount: 8);
        }
        final all = snapshot.data!
            .map((m) => _Recipient(
                uid: m.uid, displayName: m.displayName, photoURL: m.photoURL))
            .toList();
        return _buildList(context, all);
      },
    );
  }

  Widget _buildCoachList(BuildContext context) {
    final coachUid = context.watch<UserProvider>().user?.uid ?? '';
    return StreamBuilder<List<CoachClientModel>>(
      stream: CoachService().getClientsStream(coachUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AppSkeletonList(itemCount: 8);
        }
        // Only active clients are eligible recipients — matches
        // sendPlanOffer's own isEligibleRecipient check exactly.
        final all = snapshot.data!
            .where((c) => c.status == CoachClientStatus.active)
            .map((c) => _Recipient(
                uid: c.clientUid,
                displayName: c.clientDisplayName,
                photoURL: c.clientPhotoURL))
            .toList();
        return _buildList(context, all);
      },
    );
  }

  Widget _buildList(BuildContext context, List<_Recipient> all) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    if (all.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline_rounded,
        title: l10n.translate('plan_offer.picker.empty_title'),
        message: l10n.translate('plan_offer.picker.empty_message'),
      );
    }

    final filtered = _filter(all);
    if (filtered.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.translate('template_builder.library.no_results'),
        compact: true,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.xl.h),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
      itemBuilder: (context, i) {
        final r = filtered[i];
        final selected = _selectedUids.contains(r.uid);
        return AppCard(
          onTap: () => _toggle(r.uid),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.12),
                backgroundImage: r.photoURL != null
                    ? CachedNetworkImageProvider(r.photoURL!)
                    : null,
                child: r.photoURL == null
                    ? Text((r.displayName ?? '?').isNotEmpty
                        ? (r.displayName ?? '?')[0].toUpperCase()
                        : '?')
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  (r.displayName?.isNotEmpty ?? false)
                      ? r.displayName!
                      : l10n.translate('gym.member_no_name'),
                  style: AppText.of(context).bodyM.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? Theme.of(context).primaryColor
                    : palette.textTertiary,
              ),
            ],
          ),
        );
      },
    );
  }
}
