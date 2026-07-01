import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookrange/core/models/dish_model.dart';
import 'package:cookrange/core/models/user_model.dart';
import 'package:cookrange/core/providers/user_provider.dart';
import 'package:cookrange/core/services/dish_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/community_post.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/storage_upload_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/ds/app_avatar.dart';
import '../../../../core/widgets/app_image.dart';
import '../community_topics.dart';

class CreatePostCard extends StatefulWidget {
  final VoidCallback onPostCreated;

  const CreatePostCard({super.key, required this.onPostCreated});

  @override
  State<CreatePostCard> createState() => _CreatePostCardState();
}

class _CreatePostCardState extends State<CreatePostCard> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CommunityService _service = CommunityService();
  final ImagePicker _picker = ImagePicker();

  bool _isExpanded = false;
  bool _isPosting = false;
  bool _isUploadingImage = false;
  List<String> _attachedImageUrls = [];
  List<String> _selectedTags = [];
  PostType _postType = PostType.text;
  Map<String, dynamic> _metadata = {};
  String? _selectedTopic; // nullable — user may post without a topic

  // @mention state
  String? _mentionQuery;
  List<Map<String, String>> _selectedMentions = []; // [{uid, name}, ...]
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _isLoadingMentions = false;
  Timer? _mentionDebounce;

  // progress fields
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _progressLabelCtrl = TextEditingController();
  // meal fields
  final TextEditingController _mealNameCtrl = TextEditingController();
  final TextEditingController _mealCalCtrl = TextEditingController();
  final TextEditingController _mealProtCtrl = TextEditingController();
  final TextEditingController _mealCarbCtrl = TextEditingController();
  final TextEditingController _mealFatCtrl = TextEditingController();

  final List<String> _suggestedTags = [
    "🔥 Bugün trend",
    "🥦 Vegan",
    "⏱️ 15 dk",
    "💪 Spor sonrası",
    "🍳 Kolay Tarif",
    "🍝 Akşam Yemeği"
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onContentChanged);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus &&
        _controller.text.isEmpty &&
        _attachedImageUrls.isEmpty) {
      setState(() => _isExpanded = false);
    } else if (_focusNode.hasFocus) {
      setState(() => _isExpanded = true);
    }
  }

  void _onContentChanged() {
    final text = _controller.text;
    // Extract @query: find the last @ and check if we're still typing it
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final beforeCursor = text.substring(0, cursor);
    final atMatch = RegExp(r'@(\w*)$').firstMatch(beforeCursor);

    if (atMatch != null) {
      final query = atMatch.group(1) ?? '';
      if (query.isNotEmpty && query != _mentionQuery) {
        setState(() => _mentionQuery = query);
        _mentionDebounce?.cancel();
        _mentionDebounce = Timer(const Duration(milliseconds: 300), () {
          _fetchMentionSuggestions(query);
        });
      } else if (query.isEmpty) {
        // @typed but no query yet — clear suggestions
        if (_mentionQuery != null || _mentionSuggestions.isNotEmpty) {
          setState(() {
            _mentionQuery = null;
            _mentionSuggestions = [];
          });
        }
      }
    } else {
      if (_mentionQuery != null || _mentionSuggestions.isNotEmpty) {
        setState(() {
          _mentionQuery = null;
          _mentionSuggestions = [];
        });
      }
    }
  }

  Future<void> _fetchMentionSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isLoadingMentions = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('displayName')
          .startAt([query])
          .endAt(['$query'])
          .limit(5)
          .get();
      if (!mounted) return;
      setState(() {
        _mentionSuggestions = snap.docs.map((d) {
          final data = d.data();
          return {
            'uid': d.id,
            'name': (data['displayName'] as String?) ?? '',
            'photoUrl': (data['photoURL'] as String?) ?? '',
          };
        }).toList();
        _isLoadingMentions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMentions = false);
    }
  }

  void _selectMention(Map<String, dynamic> user) {
    final uid = user['uid'] as String;
    final name = user['name'] as String;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final beforeCursor = text.substring(0, cursor);
    final afterCursor = text.substring(cursor);

    // Replace the @query with @displayName + space
    final updated = beforeCursor.replaceAll(RegExp(r'@\w*$'), '@$name ');
    final newText = updated + afterCursor;
    final newCursor = updated.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    // Track in _selectedMentions (avoid duplicates)
    if (!_selectedMentions.any((m) => m['uid'] == uid)) {
      _selectedMentions.add({'uid': uid, 'name': name});
    }

    setState(() {
      _mentionQuery = null;
      _mentionSuggestions = [];
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onContentChanged);
    _mentionDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _weightCtrl.dispose();
    _progressLabelCtrl.dispose();
    _mealNameCtrl.dispose();
    _mealCalCtrl.dispose();
    _mealProtCtrl.dispose();
    _mealCarbCtrl.dispose();
    _mealFatCtrl.dispose();
    super.dispose();
  }

  void _openTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = AppPalette.of(context);
        final textStyles = AppText.of(context);
        final primaryColor = context.watch<ThemeProvider>().primaryColor;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)
                    .translate('community.create_post.add_tags'),
                style: textStyles.headlineS,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _suggestedTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          if (!_selectedTags.contains(tag)) {
                            _selectedTags.add(tag);
                          }
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                      Navigator.pop(context);
                    },
                    selectedColor: primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? primaryColor : palette.textSecondary,
                    ),
                    backgroundColor: palette.surfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      side: BorderSide(
                        color: isSelected ? primaryColor : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  Future<void> _handlePost() async {
    final content = _controller.text.trim();
    if (content.isEmpty &&
        _attachedImageUrls.isEmpty &&
        _postType == PostType.text) {
      return;
    }

    // Build metadata — always merge topic + mentions in when available
    final meta = {
      ..._buildMetadata(),
      if (_selectedTopic != null) 'topic': _selectedTopic,
      if (_selectedMentions.isNotEmpty)
        'mentions': _selectedMentions
            .map((m) => {'uid': m['uid'], 'name': m['name']})
            .toList(),
    };

    // Prepend the topic constant to tags for arrayContains filtering
    final tags = [
      if (_selectedTopic != null && !_selectedTags.contains(_selectedTopic))
        _selectedTopic!,
      ..._selectedTags,
    ];

    setState(() => _isPosting = true);

    try {
      final userModel = context.read<UserProvider>().user;
      final role = userModel?.userRole;
      final authorRole =
          (role != null && role != UserRole.consumer && role != UserRole.admin)
              ? role.firestoreValue
              : null;

      await _service.createPost(
        content,
        _attachedImageUrls,
        tags,
        postType: _postType,
        metadata: meta,
        authorRole: authorRole,
      );
      _controller.clear();
      _focusNode.unfocus();
      _weightCtrl.clear();
      _progressLabelCtrl.clear();
      _mealNameCtrl.clear();
      _mealCalCtrl.clear();
      _mealProtCtrl.clear();
      _mealCarbCtrl.clear();
      _mealFatCtrl.clear();
      setState(() {
        _attachedImageUrls = [];
        _selectedTags = [];
        _selectedTopic = null;
        _postType = PostType.text;
        _metadata = {};
        _isExpanded = false;
        _selectedMentions = [];
        _mentionSuggestions = [];
        _mentionQuery = null;
      });
      widget.onPostCreated();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final msg = e.toString().contains('content_blocked')
            ? l10n.translate('community.content_blocked')
            : "${l10n.translate('community.create_post.error')}: $e";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Map<String, dynamic> _buildMetadata() {
    switch (_postType) {
      case PostType.recipe:
        return Map<String, dynamic>.from(_metadata);
      case PostType.progress:
        final w = double.tryParse(_weightCtrl.text.trim());
        return {
          if (w != null) 'weight': w,
          if (_progressLabelCtrl.text.trim().isNotEmpty)
            'label': _progressLabelCtrl.text.trim(),
        };
      case PostType.meal:
        return {
          if (_mealNameCtrl.text.trim().isNotEmpty)
            'name': _mealNameCtrl.text.trim(),
          if (double.tryParse(_mealCalCtrl.text.trim()) != null)
            'calories': double.parse(_mealCalCtrl.text.trim()),
          if (double.tryParse(_mealProtCtrl.text.trim()) != null)
            'protein': double.parse(_mealProtCtrl.text.trim()),
          if (double.tryParse(_mealCarbCtrl.text.trim()) != null)
            'carbs': double.parse(_mealCarbCtrl.text.trim()),
          if (double.tryParse(_mealFatCtrl.text.trim()) != null)
            'fat': double.parse(_mealFatCtrl.text.trim()),
        };
      default:
        return {};
    }
  }

  Future<void> _pickImage() async {
    final userId = context.read<UserProvider>().user?.uid;
    if (userId == null) return;

    final granted = await PermissionService().requestPhotos(context);
    if (!mounted || !granted) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (image == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await StorageUploadService().uploadPostImage(
        userId: userId,
        imageFile: File(image.path),
      );
      if (mounted) {
        setState(() => _attachedImageUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _showDishPicker() async {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.read<ThemeProvider>().primaryColor;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        List<DishModel> allDishes = [];
        List<DishModel> filtered = [];
        bool loading = true;

        return StatefulBuilder(
          builder: (context, setModal) {
            if (loading) {
              DishService().getAllDishesStream().first.then((dishes) {
                setModal(() {
                  allDishes = dishes;
                  filtered = dishes;
                  loading = false;
                });
              });
            }

            void onSearch(String q) {
              final query = q.toLowerCase();
              setModal(() {
                filtered = allDishes
                    .where((d) =>
                        d.name.toLowerCase().contains(query) ||
                        d.nameEn.toLowerCase().contains(query))
                    .toList();
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              builder: (_, sc) => Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sheet)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: AppSize.sheetHandleW,
                      height: AppSize.sheetHandleH,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        l10n.translate('community.create_post.pick_recipe'),
                        style: textStyles.headlineS,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: onSearch,
                        decoration: InputDecoration(
                          hintText: l10n
                              .translate('community.create_post.search_recipe'),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: palette.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              controller: sc,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final dish = filtered[i];
                                return ListTile(
                                  leading: dish.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.sm),
                                          child: AppImage(
                                            imageUrl: dish.imageUrl!,
                                            width: 48,
                                            height: 48,
                                          ),
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: palette.surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.sm),
                                          ),
                                          child: const Icon(
                                              Icons.restaurant_rounded),
                                        ),
                                  title: Text(dish.nameEn.isNotEmpty
                                      ? dish.nameEn
                                      : dish.name),
                                  subtitle: Text(
                                      '${dish.calories.toStringAsFixed(0)} kcal · '
                                      '${dish.protein.toStringAsFixed(0)}g P · '
                                      '${dish.carbs.toStringAsFixed(0)}g C · '
                                      '${dish.fat.toStringAsFixed(0)}g F',
                                      style: textStyles.labelS),
                                  onTap: () {
                                    Navigator.pop(ctx, dish);
                                  },
                                  selectedColor: primaryColor,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((dish) {
      if (dish is DishModel && mounted) {
        setState(() {
          _postType = PostType.recipe;
          _metadata = {
            'dish_id': dish.id,
            'dish_name': dish.name,
            'dish_name_en': dish.nameEn,
            'image_url': dish.imageUrl ?? '',
            'calories': dish.calories,
            'protein': dish.protein,
            'carbs': dish.carbs,
            'fat': dish.fat,
          };
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final userImage = user?.photoURL;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: AppElevation.opacityLight),
            blurRadius: AppElevation.blurMd,
            offset: AppElevation.offsetMd,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInitialsAvatar(
                photoUrl: userImage,
                name: user?.displayName ?? '',
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: _isExpanded ? 4 : 1,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                            .translate('community.whats_cooking', variables: {
                          'name': user?.displayName?.split(' ').first ?? 'Chef'
                        }),
                        hintStyle: textStyles.bodyM,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs + 2),
                      ),
                      style:
                          textStyles.bodyL.copyWith(color: palette.textPrimary),
                    ),
                    // @mention autocomplete suggestions
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      height:
                          (_mentionSuggestions.isNotEmpty || _isLoadingMentions)
                              ? (_isLoadingMentions
                                  ? 40.0
                                  : _mentionSuggestions.length * 48.0)
                              : 0.0,
                      child: ClipRect(
                        child: (_mentionSuggestions.isEmpty &&
                                !_isLoadingMentions)
                            ? const SizedBox.shrink()
                            : Container(
                                decoration: BoxDecoration(
                                  color: palette.surfaceVariant,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(color: palette.border),
                                ),
                                child: _isLoadingMentions
                                    ? Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: primaryColor),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.zero,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _mentionSuggestions.length,
                                        itemBuilder: (_, i) {
                                          final u = _mentionSuggestions[i];
                                          final name =
                                              u['name'] as String? ?? '';
                                          final photo =
                                              u['photoUrl'] as String? ?? '';
                                          return InkWell(
                                            onTap: () => _selectMention(u),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: AppSpacing.xs,
                                                      vertical: AppSpacing.xxs),
                                              child: Row(
                                                children: [
                                                  AppInitialsAvatar(
                                                    name: name,
                                                    photoUrl: photo.isNotEmpty
                                                        ? photo
                                                        : null,
                                                    size: 28,
                                                  ),
                                                  const SizedBox(
                                                      width: AppSpacing.xs),
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: textStyles.labelM
                                                          .copyWith(
                                                              color: palette
                                                                  .textPrimary),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isExpanded ||
              _controller.text.isNotEmpty ||
              _attachedImageUrls.isNotEmpty ||
              _selectedTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),

            // Post type picker
            _PostTypePicker(
              selected: _postType,
              onSelect: (type) {
                setState(() {
                  _postType = type;
                  _metadata = {};
                });
              },
              onPickRecipe: _showDishPicker,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Per-type metadata UI
            if (_postType == PostType.recipe && _metadata.isNotEmpty)
              _RecipeAttachmentPreview(
                metadata: _metadata,
                onClear: () => setState(() => _metadata = {}),
              ),
            if (_postType == PostType.progress)
              _ProgressFields(
                  weightCtrl: _weightCtrl, labelCtrl: _progressLabelCtrl),
            if (_postType == PostType.meal)
              _MealFields(
                nameCtrl: _mealNameCtrl,
                calCtrl: _mealCalCtrl,
                protCtrl: _mealProtCtrl,
                carbCtrl: _mealCarbCtrl,
                fatCtrl: _mealFatCtrl,
              ),

            if (_postType == PostType.recipe && _metadata.isNotEmpty ||
                _postType == PostType.progress ||
                _postType == PostType.meal)
              const SizedBox(height: AppSpacing.sm),

            // Topic picker
            _TopicPicker(
              selectedTopic: _selectedTopic,
              onTopicSelected: (t) => setState(() => _selectedTopic = t),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Selected Tags
            if (_selectedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  children: _selectedTags
                      .map((tag) => Chip(
                            label: Text(tag, style: textStyles.labelS),
                            backgroundColor:
                                primaryColor.withValues(alpha: 0.1),
                            labelStyle: TextStyle(color: primaryColor),
                            deleteIcon: Icon(Icons.close,
                                size: AppSize.iconXs, color: primaryColor),
                            onDeleted: () {
                              setState(() {
                                _selectedTags.remove(tag);
                              });
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full)),
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ),

            // Attached Images Preview
            if (_attachedImageUrls.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachedImageUrls.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: AppSpacing.xs),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(
                                  _attachedImageUrls[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _attachedImageUrls.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.xxs),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (_attachedImageUrls.isNotEmpty)
              const SizedBox(height: AppSpacing.sm),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _isUploadingImage
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxs),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: primaryColor),
                            ),
                          )
                        : IconButton(
                            icon:
                                Icon(Icons.image_outlined, color: primaryColor),
                            onPressed: _pickImage,
                            tooltip: AppLocalizations.of(context)
                                .translate('community.create_post.add_image'),
                          ),
                    IconButton(
                      icon: Icon(Icons.tag, color: primaryColor),
                      onPressed: _openTagPicker,
                      tooltip: AppLocalizations.of(context)
                          .translate('community.create_post.add_tags'),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isPosting ? null : _handlePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                    elevation: 0,
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(AppLocalizations.of(context)
                          .translate('community.create_post.post_button')),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}

// ─── Post type picker ──────────────────────────────────────────────────────────

class _PostTypePicker extends StatelessWidget {
  final PostType selected;
  final ValueChanged<PostType> onSelect;
  final VoidCallback onPickRecipe;

  const _PostTypePicker({
    required this.selected,
    required this.onSelect,
    required this.onPickRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);

    final types = [
      (
        PostType.text,
        Icons.article_outlined,
        l10n.translate('community.post_type.text')
      ),
      (
        PostType.recipe,
        Icons.menu_book_rounded,
        l10n.translate('community.post_type.recipe')
      ),
      (
        PostType.progress,
        Icons.trending_up_rounded,
        l10n.translate('community.post_type.progress')
      ),
      (
        PostType.meal,
        Icons.restaurant_rounded,
        l10n.translate('community.post_type.meal')
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = selected == t.$1;
          return GestureDetector(
            onTap: () {
              if (t.$1 == PostType.recipe) {
                onSelect(PostType.recipe);
                onPickRecipe();
              } else {
                onSelect(t.$1);
              }
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.12)
                    : palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.$2,
                      size: 14,
                      color: isSelected ? primaryColor : palette.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    t.$3,
                    style: textStyles.labelS.copyWith(
                      color: isSelected ? primaryColor : palette.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Recipe attachment preview (once dish is picked) ──────────────────────────

class _RecipeAttachmentPreview extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final VoidCallback onClear;
  const _RecipeAttachmentPreview(
      {required this.metadata, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    final imageUrl = metadata['image_url'] as String?;
    final name = metadata['dish_name_en'] as String? ??
        metadata['dish_name'] as String? ??
        '';
    final cal = (metadata['calories'] as num?)?.toStringAsFixed(0) ?? '0';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: AppImage(imageUrl: imageUrl, width: 40, height: 40),
            ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: textStyles.labelM,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$cal kcal',
                    style: textStyles.labelS
                        .copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: palette.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

// ─── Progress metadata fields ──────────────────────────────────────────────────

class _ProgressFields extends StatelessWidget {
  final TextEditingController weightCtrl;
  final TextEditingController labelCtrl;
  const _ProgressFields({required this.weightCtrl, required this.labelCtrl});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InlineField(
                controller: weightCtrl,
                hint: l10n.translate('community.create_post.weight_hint'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                suffix: 'kg',
                palette: palette,
                textStyles: textStyles,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _InlineField(
          controller: labelCtrl,
          hint: l10n.translate('community.create_post.progress_label_hint'),
          palette: palette,
          textStyles: textStyles,
        ),
      ],
    );
  }
}

// ─── Meal metadata fields ──────────────────────────────────────────────────────

class _MealFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController calCtrl;
  final TextEditingController protCtrl;
  final TextEditingController carbCtrl;
  final TextEditingController fatCtrl;
  const _MealFields({
    required this.nameCtrl,
    required this.calCtrl,
    required this.protCtrl,
    required this.carbCtrl,
    required this.fatCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    const numKb = TextInputType.numberWithOptions(decimal: true);

    return Column(
      children: [
        _InlineField(
          controller: nameCtrl,
          hint: l10n.translate('community.create_post.meal_name_hint'),
          palette: palette,
          textStyles: textStyles,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _InlineField(
                controller: calCtrl,
                hint: l10n.translate('community.create_post.cal_hint'),
                keyboardType: numKb,
                inputFormatters: numFmt,
                suffix: 'kcal',
                palette: palette,
                textStyles: textStyles,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _InlineField(
                controller: protCtrl,
                hint: l10n.translate('community.create_post.prot_hint'),
                keyboardType: numKb,
                inputFormatters: numFmt,
                suffix: 'g P',
                palette: palette,
                textStyles: textStyles,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _InlineField(
                controller: carbCtrl,
                hint: l10n.translate('community.create_post.carb_hint'),
                keyboardType: numKb,
                inputFormatters: numFmt,
                suffix: 'g C',
                palette: palette,
                textStyles: textStyles,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _InlineField(
                controller: fatCtrl,
                hint: l10n.translate('community.create_post.fat_hint'),
                keyboardType: numKb,
                inputFormatters: numFmt,
                suffix: 'g F',
                palette: palette,
                textStyles: textStyles,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Topic picker row ─────────────────────────────────────────────────────────

class _TopicPicker extends StatelessWidget {
  final String? selectedTopic;
  final ValueChanged<String?> onTopicSelected;

  const _TopicPicker({
    required this.selectedTopic,
    required this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('community.topic_label'),
          style: textStyles.labelS.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs + 2),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: CommunityTopics.all.map((topic) {
              final color = CommunityTopics.colorFor(topic, palette);
              final isSelected = selectedTopic == topic;
              return GestureDetector(
                onTap: () => onTopicSelected(isSelected ? null : topic),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: isSelected ? color : palette.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    l10n.translate(CommunityTopics.labelKeyFor(topic)),
                    style: textStyles.labelS.copyWith(
                      color: isSelected ? color : palette.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Shared compact text field ─────────────────────────────────────────────────

class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffix;
  final AppPalette palette;
  final AppText textStyles;

  const _InlineField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
    required this.palette,
    required this.textStyles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: textStyles.bodyM,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    textStyles.bodyM.copyWith(color: palette.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (suffix != null)
            Text(suffix!,
                style:
                    textStyles.labelS.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}
