import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/data/turkish_locations.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/gym_service.dart';
import '../../core/utils/haversine.dart';
import '../../core/widgets/ds/ds.dart';
import 'gym_dashboard_screen.dart';
import 'gym_join_prompt_sheet.dart';
import 'gym_member_home_screen.dart';

/// Gym discovery screen — search and join public gyms.
/// Supports city/district filtering, A-Z/Popular/Newest/Near Me sorting,
/// and an optional map view powered by flutter_map + OpenStreetMap.
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
  String? _selectedCity;
  String? _selectedDistrict;
  String _sortBy = 'member_count';

  // Near Me state
  double? _userLat;
  double? _userLon;
  bool _loadingLocation = false;

  // Map view state
  bool _mapView = false;

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
      // When sorting by distance we fetch all (no pagination cursor) so
      // client-side sorting is accurate; otherwise use normal cursor pagination.
      final results = await GymService().searchGyms(
        _query,
        city: _selectedCity,
        district: _selectedDistrict,
        sortBy: _sortBy == 'near_me' ? 'member_count' : _sortBy,
        startAfter: (_sortBy == 'near_me' || !more) ? null : _lastDoc,
        limit: _sortBy == 'near_me' ? 200 : 20,
      );
      if (!mounted) return;

      List<GymModel> merged;
      if (more && _sortBy != 'near_me') {
        merged = [..._gyms, ...results];
      } else {
        merged = results;
      }

      // Client-side distance sort
      if (_sortBy == 'near_me' && _userLat != null && _userLon != null) {
        merged.sort((a, b) {
          final da = (a.latitude != null && a.longitude != null)
              ? haversineKm(_userLat!, _userLon!, a.latitude!, a.longitude!)
              : double.infinity;
          final db = (b.latitude != null && b.longitude != null)
              ? haversineKm(_userLat!, _userLon!, b.latitude!, b.longitude!)
              : double.infinity;
          return da.compareTo(db);
        });
      }

      setState(() {
        _gyms = merged;
        _hasMore = _sortBy == 'near_me' ? false : results.length == 20;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _activateNearMe() async {
    final l10n = AppLocalizations.of(context);

    // Check permission first — skip the KVKK primer entirely if already granted.
    final existing = await Geolocator.checkPermission();
    if (!mounted) return;

    if (existing != LocationPermission.whileInUse &&
        existing != LocationPermission.always) {
      // Permission not yet granted — show KVKK/GDPR primer before OS dialog.
      final consent = await PermissionPrimer.show(
        context,
        icon: Icons.location_on_rounded,
        iconColor: AppPalette.of(context).warning,
        title: l10n.translate('gym.nearby_consent_title'),
        rationale: l10n.translate('gym.nearby_consent_rationale'),
        allowLabel: l10n.translate('permission.allow'),
        notNowLabel: l10n.translate('permission.not_now'),
      );
      if (!mounted) return;
      if (!consent) {
        setState(() => _sortBy = 'member_count');
        return;
      }
    }

    setState(() => _loadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _sortBy = 'member_count';
        });
        AppSnackBar.warning(
          context,
          AppLocalizations.of(context).translate('gym.location_denied'),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLon = pos.longitude;
        _loadingLocation = false;
        _gyms = [];
        _lastDoc = null;
        _hasMore = true;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _sortBy = 'member_count';
      });
      AppSnackBar.error(
        context,
        AppLocalizations.of(context).translate('gym.location_error'),
      );
    }
  }

  void _openGymDetails(GymModel gym) {
    _showGymPublicSheet(context, gym, onQrJoin: () => _startQrJoin(gym));
  }

  Future<void> _startQrJoin(GymModel gym) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!mounted) return;
    final result = await Navigator.push<({String gymId, String token})?>(
      context,
      AppTransitions.slideUp(_GymQrJoinPage(gym: gym)),
    );
    if (!mounted || result == null) return;
    await GymJoinPromptSheet.show(
      context,
      gymId: result.gymId,
      gymName: gym.name,
      uid: uid,
      qrToken: result.token,
    );
  }

  // Distance label string for a gym when Near Me is active.
  String? _distanceLabel(GymModel gym) {
    if (_sortBy != 'near_me' || _userLat == null || _userLon == null) {
      return null;
    }
    if (gym.latitude == null || gym.longitude == null) return null;
    final km = haversineKm(_userLat!, _userLon!, gym.latitude!, gym.longitude!);
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
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
        actions: [
          // Map / List toggle
          IconButton(
            icon: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                _mapView ? Icons.list_rounded : Icons.map_outlined,
                key: ValueKey(_mapView),
                color: _mapView ? primary : palette.textSecondary,
                size: 22,
              ),
            ),
            tooltip: _mapView
                ? l10n.translate('gym.toggle_list')
                : l10n.translate('gym.toggle_map'),
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              setState(() => _mapView = !_mapView);
            },
          ),
          const SizedBox(width: 4),
        ],
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
          _FilterBar(
            selectedCity: _selectedCity,
            selectedDistrict: _selectedDistrict,
            sortBy: _sortBy,
            loadingLocation: _loadingLocation,
            onCityChanged: (city) {
              setState(() {
                _selectedCity = city;
                _selectedDistrict = null;
                _gyms = [];
                _lastDoc = null;
                _hasMore = true;
              });
              unawaited(_load());
            },
            onDistrictChanged: (district) {
              setState(() {
                _selectedDistrict = district;
                _gyms = [];
                _lastDoc = null;
                _hasMore = true;
              });
              unawaited(_load());
            },
            onSortChanged: (sort) {
              setState(() {
                _sortBy = sort;
                _gyms = [];
                _lastDoc = null;
                _hasMore = true;
              });
              if (sort == 'near_me') {
                unawaited(_activateNearMe());
              } else {
                unawaited(_load());
              }
            },
            palette: palette,
            l10n: l10n,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.normal,
              child: _mapView
                  ? _GymMapView(
                      key: const ValueKey('map'),
                      gyms: _gyms,
                      userLat: _userLat,
                      userLon: _userLon,
                      onQrJoin: _startQrJoin,
                    )
                  : RefreshIndicator(
                      key: const ValueKey('list'),
                      color: primary,
                      onRefresh: () => _load(),
                      child: _buildList(context, palette, l10n),
                    ),
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
          if (!_loading) _load(more: true);
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _GymCard(
          gym: _gyms[i],
          onDetails: () => _openGymDetails(_gyms[i]),
          distanceLabel: _distanceLabel(_gyms[i]),
        );
      },
    );
  }
}

// ── Map View ──────────────────────────────────────────────────────────────────

class _GymMapView extends StatelessWidget {
  final List<GymModel> gyms;
  final double? userLat;
  final double? userLon;
  final Future<void> Function(GymModel)? onQrJoin;

  const _GymMapView({
    super.key,
    required this.gyms,
    required this.userLat,
    required this.userLon,
    this.onQrJoin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    final hasUserPos = userLat != null && userLon != null;
    final center = hasUserPos
        ? LatLng(userLat!, userLon!)
        : const LatLng(39.9334, 32.8597); // Turkey centre
    final zoom = hasUserPos ? 13.0 : 6.0;

    final gymMarkers = gyms
        .where((g) => g.latitude != null && g.longitude != null)
        .map(
          (g) => Marker(
            point: LatLng(g.latitude!, g.longitude!),
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => _showGymSheet(context, g, palette, l10n),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppPalette.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        )
        .toList();

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cookrange_android.app',
              ),
              MarkerLayer(markers: gymMarkers),
              if (hasUserPos)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(userLat!, userLon!),
                      width: 20,
                      height: 20,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: palette.info,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: palette.info.withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // ── Gym list panel ──────────────────────────────────────────
        _GymMapList(
          gyms: gyms,
          onTap: (g) => _showGymSheet(context, g, palette, l10n),
          palette: palette,
          l10n: l10n,
        ),
      ],
    );
  }

  void _showGymSheet(
    BuildContext context,
    GymModel gym,
    AppPalette palette,
    AppLocalizations l10n,
  ) {
    _showGymPublicSheet(context, gym,
        onQrJoin: onQrJoin != null ? () => onQrJoin!(gym) : null);
  }
}

// ── Gym map list panel ────────────────────────────────────────────────────────

class _GymMapList extends StatelessWidget {
  final List<GymModel> gyms;
  final void Function(GymModel) onTap;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _GymMapList({
    required this.gyms,
    required this.onTap,
    required this.palette,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (gyms.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).primaryColor;

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        physics: const BouncingScrollPhysics(),
        itemCount: gyms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final gym = gyms[i];
          return GestureDetector(
            onTap: () => onTap(gym),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: gym.logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Image.network(gym.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _initials(gym.name, primary)),
                          )
                        : _initials(gym.name, primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                gym.name,
                                style: AppText.of(context).bodyM.copyWith(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (gym.isVerified) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.verified_rounded,
                                  size: 12, color: Colors.blue.shade400),
                            ],
                          ],
                        ),
                        if (gym.locationDisplay.isNotEmpty)
                          Text(
                            gym.locationDisplay,
                            style: TextStyle(
                                fontSize: 11, color: palette.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '${gym.memberCount} ${l10n.translate('gym.stat_members')}',
                          style: TextStyle(
                              fontSize: 10, color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _initials(String name, Color primary) {
    final init = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : '?';
    return Center(
      child: Text(init,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: primary)),
    );
  }
}

// ── Sheet info row helper ─────────────────────────────────────────────────────

class _SheetInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppPalette palette;
  final Color? color;

  const _SheetInfoRow({
    required this.icon,
    required this.text,
    required this.palette,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: textColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: AppText.of(context).bodyM.copyWith(color: textColor)),
          ),
        ],
      ),
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
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'Something went wrong',
            message: snapshot.error.toString(),
            onRetry: () {},
          );
        }
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          gym.name,
                          style: AppText.of(context).bodyM.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (gym.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded,
                            size: 14, color: Colors.blue.shade400),
                      ],
                    ],
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
  final VoidCallback onDetails;
  final String? distanceLabel;

  const _GymCard({
    required this.gym,
    required this.onDetails,
    this.distanceLabel,
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          gym.name,
                          style: AppText.of(context).bodyM.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (gym.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded,
                            size: 14, color: Colors.blue.shade400),
                      ],
                      // Distance badge
                      if (distanceLabel != null) ...[
                        const SizedBox(width: 6),
                        _DistanceBadge(label: distanceLabel!, palette: palette),
                      ],
                    ],
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
                      Flexible(
                        child: Text(
                          '${gym.memberCount} ${l10n.translate('gym.stat_members')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (gym.tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: gym.tags
                                .take(2)
                                .map(
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
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
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
              label: l10n.translate('gym.details_btn'),
              onPressed: onDetails,
              variant: AppButtonVariant.tonal,
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

// ── Distance badge pill ───────────────────────────────────────────────────────

class _DistanceBadge extends StatelessWidget {
  final String label;
  final AppPalette palette;

  const _DistanceBadge({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.energy.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: palette.energy.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, size: 10, color: palette.energy),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: palette.energy,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String? selectedCity;
  final String? selectedDistrict;
  final String sortBy;
  final bool loadingLocation;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String> onSortChanged;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _FilterBar({
    required this.selectedCity,
    required this.selectedDistrict,
    required this.sortBy,
    required this.loadingLocation,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.onSortChanged,
    required this.palette,
    required this.l10n,
  });

  void _showCityPicker(BuildContext context) {
    final cities = TurkishLocations.provinces;
    AppSheet.show(
      context: context,
      title: l10n.translate('discovery.filter_city'),
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: Icon(Icons.clear_rounded,
                size: 18.r, color: palette.textTertiary),
            title: Text(l10n.translate('discovery.filter_all'),
                style: TextStyle(color: palette.textSecondary)),
            onTap: () {
              Navigator.pop(context);
              onCityChanged(null);
            },
          ),
          ...cities.map((city) => ListTile(
                title: Text(city,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: selectedCity == city
                          ? FontWeight.w700
                          : FontWeight.normal,
                    )),
                trailing: selectedCity == city
                    ? Icon(Icons.check_rounded, color: palette.info, size: 18.r)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onCityChanged(city);
                },
              )),
        ],
      ),
    );
  }

  void _showDistrictPicker(BuildContext context) {
    if (selectedCity == null) return;
    final districts = TurkishLocations.districtsOf(selectedCity!);
    AppSheet.show(
      context: context,
      title: l10n.translate('discovery.filter_district'),
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: Icon(Icons.clear_rounded,
                size: 18.r, color: palette.textTertiary),
            title: Text(l10n.translate('discovery.filter_all'),
                style: TextStyle(color: palette.textSecondary)),
            onTap: () {
              Navigator.pop(context);
              onDistrictChanged(null);
            },
          ),
          ...districts.map((d) => ListTile(
                title: Text(d,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: selectedDistrict == d
                          ? FontWeight.w700
                          : FontWeight.normal,
                    )),
                trailing: selectedDistrict == d
                    ? Icon(Icons.check_rounded, color: palette.info, size: 18.r)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onDistrictChanged(d);
                },
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFilter = selectedCity != null || sortBy != 'member_count';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterBar(
          children: [
            // ── Location filters ─────────────────────────────────────
            AppFilterPill.picker(
              icon: Icons.location_city_rounded,
              label: selectedCity ?? l10n.translate('discovery.filter_city'),
              active: selectedCity != null,
              onTap: () => _showCityPicker(context),
            ),
            if (selectedCity != null)
              AppFilterPill.picker(
                icon: Icons.map_outlined,
                label: selectedDistrict ??
                    l10n.translate('discovery.filter_district'),
                active: selectedDistrict != null,
                onTap: () => _showDistrictPicker(context),
              ),
            const AppFilterDivider(),
            // ── Sort chips ───────────────────────────────────────────
            AppFilterPill(
              icon: Icons.star_rounded,
              label: l10n.translate('discovery.sort_top_rated'),
              active: sortBy == 'avg_rating',
              onTap: () => onSortChanged('avg_rating'),
            ),
            AppFilterPill(
              icon: Icons.local_fire_department_rounded,
              label: l10n.translate('discovery.sort_popular'),
              active: sortBy == 'member_count',
              onTap: () => onSortChanged('member_count'),
            ),
            AppFilterPill(
              icon: Icons.new_releases_rounded,
              label: l10n.translate('discovery.sort_newest'),
              active: sortBy == 'created_at',
              onTap: () => onSortChanged('created_at'),
            ),
            AppFilterPill(
              icon: Icons.near_me_rounded,
              label: l10n.translate('discovery.sort_near_me'),
              active: sortBy == 'near_me',
              accent: palette.energy,
              loading: loadingLocation,
              onTap: loadingLocation ? null : () => onSortChanged('near_me'),
            ),
          ],
        ),
        if (hasFilter)
          Padding(
            padding: EdgeInsets.only(left: 16.w, top: 4.h, bottom: 2.h),
            child: GestureDetector(
              onTap: () {
                onCityChanged(null);
                onSortChanged('member_count');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 12.r, color: palette.textTertiary),
                  SizedBox(width: 4.w),
                  Text(
                    l10n.translate('discovery.filter_clear'),
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.textTertiary,
                          fontSize: 11.sp,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Gym public detail sheet ───────────────────────────────────────────────────

/// Shows a public-facing gym detail bottom sheet.
/// [onQrJoin] is called (after the sheet closes) when the user taps the QR join
/// button; leave null to hide the join option.
void _showGymPublicSheet(
  BuildContext context,
  GymModel gym, {
  VoidCallback? onQrJoin,
}) {
  final palette = AppPalette.of(context);
  final l10n = AppLocalizations.of(context);
  final primary = Theme.of(context).primaryColor;

  AppSheet.show(
    context: context,
    title: gym.name,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gym.address != null && gym.address!.isNotEmpty)
          _SheetInfoRow(
            icon: Icons.location_on_rounded,
            text: gym.address!,
            palette: palette,
          ),
        if (gym.locationDisplay.isNotEmpty)
          _SheetInfoRow(
            icon: Icons.location_city_rounded,
            text: gym.locationDisplay,
            palette: palette,
          ),
        _SheetInfoRow(
          icon: Icons.people_rounded,
          text: '${gym.memberCount} ${l10n.translate('gym.stat_members')}',
          palette: palette,
          color: palette.textTertiary,
        ),
        if (gym.description != null && gym.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            gym.description!,
            style: AppText.of(context)
                .bodyM
                .copyWith(color: palette.textSecondary),
          ),
        ],
        if (gym.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: gym.tags
                .take(5)
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                            fontSize: 11,
                            color: primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 20),
        if (onQrJoin != null)
          AppButton(
            label: l10n.translate('gym.join_qr_btn'),
            onPressed: () {
              Navigator.of(context).pop();
              onQrJoin();
            },
            icon: Icons.qr_code_scanner_rounded,
          ),
        if (onQrJoin != null) const SizedBox(height: 8),
        AppButton(
          label: l10n.translate('gym.map_view_gym'),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              AppTransitions.slideRight(GymMemberHomeScreen(gym: gym)),
            );
          },
          icon: Icons.arrow_forward_rounded,
          variant: onQrJoin != null
              ? AppButtonVariant.secondary
              : AppButtonVariant.primary,
          size: AppButtonSize.medium,
        ),
      ],
    ),
  );
}

// ── QR Join Page ──────────────────────────────────────────────────────────────

/// Full-screen QR scanner for joining a gym via invite QR code.
/// Pops with `({gymId, token})` on a valid scan, or null on cancel.
class _GymQrJoinPage extends StatefulWidget {
  final GymModel gym;
  const _GymQrJoinPage({required this.gym});

  @override
  State<_GymQrJoinPage> createState() => _GymQrJoinPageState();
}

class _GymQrJoinPageState extends State<_GymQrJoinPage> {
  late MobileScannerController _ctrl;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    // Expected: cookrange:checkin:{gymId}:{token}
    final parts = raw.split(':');
    if (parts.length != 4 ||
        parts[0] != 'cookrange' ||
        parts[1] != 'checkin' ||
        parts[2] != widget.gym.id) {
      if (mounted) {
        AppSnackBar.error(
          context,
          AppLocalizations.of(context).translate('gym.checkin_invalid_qr'),
        );
      }
      return;
    }

    setState(() => _processing = true);
    if (!mounted) return;
    Navigator.of(context).pop<({String gymId, String token})?>(
        (gymId: widget.gym.id, token: parts[3]));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('gym.join_qr_title'),
          style: t.titleM.copyWith(color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          // Subtitle
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Text(
              l10n.translate('gym.join_qr_subtitle'),
              textAlign: TextAlign.center,
              style: t.bodyM.copyWith(color: Colors.white70),
            ),
          ),
          if (_processing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
