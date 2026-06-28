import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/gym_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'gym_dashboard_screen.dart';
import 'gym_member_home_screen.dart';

/// Gym discovery screen — search and join public gyms.
class GymDiscoveryScreen extends StatefulWidget {
  const GymDiscoveryScreen({super.key});

  @override
  State<GymDiscoveryScreen> createState() => _GymDiscoveryScreenState();
}

class _GymDiscoveryScreenState extends State<GymDiscoveryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<GymModel> _gyms = [];
  bool _loading = false;
  String _query = '';
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;

  final Set<String> _joiningIds = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (v == _query) return;
      setState(() {
        _query = v;
        _gyms = [];
        _lastDoc = null;
        _hasMore = true;
      });
      _load();
    });
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    if (more && !_hasMore) return;
    setState(() => _loading = true);

    try {
      final results = await GymService().searchGyms(
        _query,
        startAfter: more ? _lastDoc : null,
      );
      if (!mounted) return;
      setState(() {
        if (more) {
          _gyms.addAll(results);
        } else {
          _gyms = results;
        }
        _hasMore = results.length == 20;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleJoin(GymModel gym) async {
    if (_joiningIds.contains(gym.id)) return;
    setState(() => _joiningIds.add(gym.id));
    unawaited(HapticFeedback.mediumImpact());

    try {
      final isMember = await GymService().isMember(
          gym.id, gym.ownerUid /* won't match, just checking existence */);
      if (isMember) {
        await GymService().leaveGym(gym.id);
      } else {
        await GymService().joinGym(gym.id);
      }
      if (!mounted) return;
      // Refresh gym in list with updated count
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        AppLocalizations.of(context).translate('gym.join_error'),
      );
    } finally {
      if (mounted) setState(() => _joiningIds.remove(gym.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('gym.discovery_title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: Column(
        children: [
          _MyGymsStrip(palette: palette, l10n: l10n),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppTextField(
              controller: _searchCtrl,
              hintText: l10n.translate('gym.discovery_search_hint'),
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: primary,
              onRefresh: () => _load(),
              child: _buildList(context, palette, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppPalette palette,
    AppLocalizations l10n,
  ) {
    if (_loading && _gyms.isEmpty) {
      return const AppSkeletonList();
    }

    if (_gyms.isEmpty) {
      return AppEmptyState(
        icon: Icons.fitness_center_rounded,
        title: l10n.translate('gym.discovery_empty_title'),
        message: l10n.translate('gym.discovery_empty_sub'),
        actionLabel: l10n.translate('gym.discovery_cta'),
        onAction: () => Navigator.of(context).push(
          AppTransitions.slideRight(const GymDashboardScreen()),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _gyms.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _gyms.length) {
          // Load more trigger
          if (!_loading) _load(more: true);
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _GymCard(
          gym: _gyms[i],
          isJoining: _joiningIds.contains(_gyms[i].id),
          onJoin: () => _toggleJoin(_gyms[i]),
        );
      },
    );
  }
}

// ── My Gyms strip (gyms the user has joined) ──────────────────────────────────

class _MyGymsStrip extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;

  const _MyGymsStrip({required this.palette, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<GymModel>>(
      stream: GymService().getMemberGymsStream(uid),
      builder: (context, snapshot) {
        final gyms = snapshot.data ?? const <GymModel>[];
        if (gyms.isEmpty) return const SizedBox.shrink();

        return RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  l10n.translate('gym.my_gyms').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary.withValues(alpha: 0.65),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: gyms.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) =>
                      _MyGymChip(gym: gyms[i], palette: palette),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: palette.border.withValues(alpha: 0.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyGymChip extends StatelessWidget {
  final GymModel gym;
  final AppPalette palette;

  const _MyGymChip({required this.gym, required this.palette});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return SizedBox(
      width: 200,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          AppTransitions.slideRight(GymMemberHomeScreen(gym: gym)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: gym.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        gym.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _initials(gym.name, primary),
                      ),
                    )
                  : _initials(gym.name, primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gym.name,
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (gym.locationDisplay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      gym.locationDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _initials(String name, Color primary) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
      ),
    );
  }
}

// ── Gym card ──────────────────────────────────────────────────────────────────

class _GymCard extends StatelessWidget {
  final GymModel gym;
  final bool isJoining;
  final VoidCallback onJoin;

  const _GymCard({
    required this.gym,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Logo / initials
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: gym.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        gym.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _initials(gym.name, primary),
                      ),
                    )
                  : _initials(gym.name, primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gym.name,
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (gym.locationDisplay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: palette.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            gym.locationDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          size: 12, color: palette.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${gym.memberCount} ${l10n.translate('gym.stat_members')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textTertiary,
                        ),
                      ),
                      if (gym.tags.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ...gym.tags.take(2).map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AppButton(
              label: l10n.translate('gym.join_btn'),
              onPressed: onJoin,
              loading: isJoining,
              size: AppButtonSize.small,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials(String name, Color primary) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
      ),
    );
  }
}
