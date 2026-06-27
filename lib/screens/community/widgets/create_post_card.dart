import 'dart:io';
import 'package:cookrange/core/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/services/storage_upload_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';

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

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
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
                      color: isSelected
                          ? primaryColor
                          : palette.textSecondary,
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
    if (content.isEmpty && _attachedImageUrls.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await _service.createPost(content, _attachedImageUrls, _selectedTags);
      _controller.clear();
      _focusNode.unfocus();
      setState(() {
        _attachedImageUrls = [];
        _selectedTags = [];
        _isExpanded = false;
      });
      widget.onPostCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "${AppLocalizations.of(context).translate('community.create_post.error')}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _pickImage() async {
    final userId = context.read<UserProvider>().user?.uid;
    if (userId == null) return;

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
              CircleAvatar(
                backgroundImage: NetworkImage(
                    userImage ?? 'https://i.pravatar.cc/150?u=current'),
                radius: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
                  ),
                  style: textStyles.bodyL.copyWith(color: palette.textPrimary),
                ),
              ),
            ],
          ),
          if (_isExpanded ||
              _controller.text.isNotEmpty ||
              _attachedImageUrls.isNotEmpty ||
              _selectedTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),

            // Selected Tags
            if (_selectedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  children: _selectedTags
                      .map((tag) => Chip(
                            label: Text(tag,
                                style: textStyles.labelS),
                            backgroundColor:
                                primaryColor.withValues(alpha: 0.1),
                            labelStyle: TextStyle(color: primaryColor),
                            deleteIcon: Icon(Icons.close,
                                size: AppSize.iconXs,
                                color: primaryColor),
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
                              image: NetworkImage(_attachedImageUrls[index]),
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
                            icon: Icon(Icons.image_outlined,
                                color: primaryColor),
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
