import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/data/turkish_locations.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/widgets/ds/ds.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String? _city;
  String? _district;
  bool _isPublic = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _showCityPicker() {
    final l10n = AppLocalizations.of(context);
    AppSheet.show(
      context: context,
      title: l10n.translate('community.groups.city_label'),
      child: _OptionList(
        options: TurkishLocations.provinces,
        onSelected: (v) {
          Navigator.pop(context);
          setState(() {
            _city = v;
            _district = null;
          });
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
      child: _OptionList(
        options: TurkishLocations.districtsOf(city),
        onSelected: (v) {
          Navigator.pop(context);
          setState(() => _district = v);
        },
      ),
    );
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
      await CommunityGroupService().createGroup(
        name: name,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        city: _city,
        district: _district,
        tags: tags,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(
          context, l10n.translate('community.groups.created_success'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: palette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.translate('community.groups.create_title'),
            style: t.titleM.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 40.h),
        children: [
          _label(l10n.translate('community.groups.name_label'), t, palette),
          AppTextField(
            controller: _nameCtrl,
            hintText: l10n.translate('community.groups.name_hint'),
          ),
          SizedBox(height: 16.h),
          _label(
              l10n.translate('community.groups.description_label'), t, palette),
          AppTextField(
            controller: _descCtrl,
            hintText: l10n.translate('community.groups.description_hint'),
            maxLines: 3,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  icon: Icons.location_city_rounded,
                  label: l10n.translate('community.groups.city_label'),
                  value: _city,
                  onTap: _showCityPicker,
                  palette: palette,
                  t: t,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _PickerField(
                  icon: Icons.map_outlined,
                  label: l10n.translate('community.groups.district_label'),
                  value: _district,
                  onTap: _city == null ? null : _showDistrictPicker,
                  palette: palette,
                  t: t,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _label(l10n.translate('community.groups.tags_label'), t, palette),
          AppTextField(
            controller: _tagsCtrl,
            hintText: l10n.translate('community.groups.tags_hint'),
          ),
          SizedBox(height: 16.h),
          SwitchListTile.adaptive(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.translate('community.groups.public_label'),
                style: t.bodyM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(l10n.translate('community.groups.public_sub'),
                style: t.labelS.copyWith(color: palette.textTertiary)),
          ),
          SizedBox(height: 24.h),
          AppButton(
            label: l10n.translate('community.groups.create'),
            icon: Icons.groups_rounded,
            loading: _saving,
            onPressed:
                _saving || _nameCtrl.text.trim().isEmpty ? null : _create,
          ),
        ],
      ),
    );
  }

  Widget _label(String text, AppText t, AppPalette palette) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child:
            Text(text, style: t.labelM.copyWith(color: palette.textSecondary)),
      );
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final AppPalette palette;
  final AppText t;

  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: palette.surfaceVariant.withValues(alpha: disabled ? 0.4 : 1),
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16.r,
                color: disabled ? palette.textTertiary : palette.textSecondary),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                value ?? label,
                style: t.bodyM.copyWith(
                    color: value != null
                        ? palette.textPrimary
                        : palette.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18.r, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _OptionList extends StatelessWidget {
  final List<String> options;
  final ValueChanged<String> onSelected;
  const _OptionList({required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SizedBox(
      height: 420.h,
      child: ListView(
        children: options
            .map((o) => ListTile(
                  title: Text(o, style: t.bodyM),
                  onTap: () => onSelected(o),
                ))
            .toList(),
      ),
    );
  }
}
