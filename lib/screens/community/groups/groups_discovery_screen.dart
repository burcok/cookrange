import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/turkish_locations.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/community_group_model.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/widgets/ds/ds.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

/// Location-based community group discovery. Defaults the city filter to the
/// user's last choice (remembered in prefs), filterable by district, sortable
/// by activity / members / newest.
class GroupsDiscoveryScreen extends StatefulWidget {
  const GroupsDiscoveryScreen({super.key});

  @override
  State<GroupsDiscoveryScreen> createState() => _GroupsDiscoveryScreenState();
}

class _GroupsDiscoveryScreenState extends State<GroupsDiscoveryScreen> {
  static const _prefsCity = 'groups_last_city';
  static const _prefsDistrict = 'groups_last_district';

  final _service = CommunityGroupService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  String? _city;
  String? _district;
  String _sortBy = 'last_activity_at';
  List<CommunityGroupModel> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreAndLoad();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _city = prefs.getString(_prefsCity);
    _district = prefs.getString(_prefsDistrict);
    await _load();
  }

  Future<void> _persistLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (_city == null) {
      await prefs.remove(_prefsCity);
    } else {
      await prefs.setString(_prefsCity, _city!);
    }
    if (_district == null) {
      await prefs.remove(_prefsDistrict);
    } else {
      await prefs.setString(_prefsDistrict, _district!);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await _service.searchGroups(
      query: _query,
      city: _city,
      district: _district,
      sortBy: _sortBy,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (v.trim() == _query) return;
      _query = v.trim();
      _load();
    });
  }

  void _showCityPicker() {
    final l10n = AppLocalizations.of(context);
    AppSheet.show(
      context: context,
      title: l10n.translate('community.groups.city_label'),
      child: _PickerList(
        options: TurkishLocations.provinces,
        includeAll: true,
        allLabel: l10n.translate('discovery.filter_all_cities'),
        onSelected: (v) {
          Navigator.pop(context);
          setState(() {
            _city = v;
            _district = null;
          });
          _persistLocation();
          _load();
        },
      ),
    );
  }

  void _showDistrictPicker() {
    final city = _city;
    if (city == null) return;
    final l10n = AppLocalizations.of(context);
    AppSheet.show(
      context: context,
      title: l10n.translate('community.groups.district_label'),
      child: _PickerList(
        options: TurkishLocations.districtsOf(city),
        includeAll: true,
        allLabel: l10n.translate('discovery.filter_all_districts'),
        onSelected: (v) {
          Navigator.pop(context);
          setState(() => _district = v);
          _persistLocation();
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final uid = context.watch<UserProvider>().user?.uid;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('community.groups.title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            AppTransitions.slideUp(const CreateGroupScreen()),
          );
          if (created == true) unawaited(_load());
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.translate('community.groups.create')),
      ),
      body: Column(
        children: [
          if (uid != null) _MyGroupsStrip(uid: uid, service: _service),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppTextField(
              controller: _searchCtrl,
              hintText: l10n.translate('community.groups.discover'),
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
          AppFilterBar(
            children: [
              AppFilterPill.picker(
                icon: Icons.location_city_rounded,
                label: _city ?? l10n.translate('discovery.filter_city'),
                active: _city != null,
                onTap: _showCityPicker,
              ),
              if (_city != null)
                AppFilterPill.picker(
                  icon: Icons.map_outlined,
                  label:
                      _district ?? l10n.translate('discovery.filter_district'),
                  active: _district != null,
                  onTap: _showDistrictPicker,
                ),
              const AppFilterDivider(),
              AppFilterPill(
                icon: Icons.local_fire_department_rounded,
                label: l10n.translate('community.groups.sort_active'),
                active: _sortBy == 'last_activity_at',
                onTap: () {
                  setState(() => _sortBy = 'last_activity_at');
                  _load();
                },
              ),
              AppFilterPill(
                icon: Icons.groups_rounded,
                label: l10n.translate('community.groups.sort_popular'),
                active: _sortBy == 'member_count',
                onTap: () {
                  setState(() => _sortBy = 'member_count');
                  _load();
                },
              ),
              AppFilterPill(
                icon: Icons.new_releases_rounded,
                label: l10n.translate('community.groups.sort_newest'),
                active: _sortBy == 'created_at',
                onTap: () {
                  setState(() => _sortBy = 'created_at');
                  _load();
                },
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: _loading
                ? const AppSkeletonList()
                : _results.isEmpty
                    ? AppEmptyState(
                        icon: Icons.groups_2_rounded,
                        title: l10n
                            .translate('community.groups.discover_empty_title'),
                        message: l10n
                            .translate('community.groups.discover_empty_msg'),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 10.h),
                          itemBuilder: (ctx, i) =>
                              _GroupCard(group: _results[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final CommunityGroupModel group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(
        AppTransitions.slideRight(GroupDetailScreen(groupId: group.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.groups_rounded, color: primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: t.bodyM.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (group.locationDisplay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 12, color: palette.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(group.locationDisplay,
                            style: TextStyle(
                                fontSize: 12, color: palette.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  l10n
                      .translate('community.groups.members_count')
                      .replaceAll('{n}', '${group.memberCount}'),
                  style: TextStyle(fontSize: 11, color: palette.textTertiary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
        ],
      ),
    );
  }
}

class _MyGroupsStrip extends StatelessWidget {
  final String uid;
  final CommunityGroupService service;
  const _MyGroupsStrip({required this.uid, required this.service});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<CommunityGroupModel>>(
      stream: service.getMyGroupsStream(uid),
      builder: (context, snap) {
        final groups = snap.data ?? const <CommunityGroupModel>[];
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Text(
                l10n.translate('community.groups.my_groups').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary.withValues(alpha: 0.65),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final g = groups[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      AppTransitions.slideRight(
                          GroupDetailScreen(groupId: g.id)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: palette.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(g.name,
                          style: AppText.of(context).labelM.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
            ),
            Divider(
                height: 1,
                thickness: 1,
                color: palette.border.withValues(alpha: 0.4)),
          ],
        );
      },
    );
  }
}

/// Simple selectable list used inside the city/district picker sheets.
class _PickerList extends StatelessWidget {
  final List<String> options;
  final bool includeAll;
  final String allLabel;
  final ValueChanged<String?> onSelected;

  const _PickerList({
    required this.options,
    required this.includeAll,
    required this.allLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return SizedBox(
      height: 420.h,
      child: ListView(
        children: [
          if (includeAll)
            ListTile(
              title: Text(allLabel, style: t.bodyM),
              onTap: () => onSelected(null),
            ),
          ...options.map((o) => ListTile(
                title: Text(o,
                    style: t.bodyM.copyWith(color: palette.textPrimary)),
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onSelected(o);
                },
              )),
        ],
      ),
    );
  }
}
