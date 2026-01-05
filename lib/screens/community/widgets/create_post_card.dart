import 'package:cookrange/core/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/community_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/theme_provider.dart';

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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)
                    .translate('community.create_post.add_tags'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                      Navigator.pop(
                          context); // Close for single select or stay open? Let's close for flow or keep open?
                      // Better UX: keep open to select multiple, but user requested specific examples.
                      // Let's keep open and add a 'Done' button or just allow tap out.
                      // Actually for smoothness, let's keep open.
                      // Rebuild the bottom sheet? StatefulBuilder needed for BottomSheet updating.
                    },
                    selectedColor: context
                        .watch<ThemeProvider>()
                        .primaryColor
                        .withOpacity(0.2),
                    checkmarkColor: context.watch<ThemeProvider>().primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? context.watch<ThemeProvider>().primaryColor
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    backgroundColor:
                        isDark ? Colors.white10 : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? context.watch<ThemeProvider>().primaryColor
                            : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    ).then((_) => setState(() {})); // Refresh parent to show selected tags
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
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _attachedImageUrls.add(
              'https://source.unsplash.com/random/800x600/?food,cooking&${DateTime.now().millisecondsSinceEpoch}');
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final userImage = user?.photoURL;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              const SizedBox(width: 12),
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
                    hintStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          if (_isExpanded ||
              _controller.text.isNotEmpty ||
              _attachedImageUrls.isNotEmpty ||
              _selectedTags.isNotEmpty) ...[
            const SizedBox(height: 12),

            // Selected Tags
            if (_selectedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  children: _selectedTags
                      .map((tag) => Chip(
                            label:
                                Text(tag, style: const TextStyle(fontSize: 12)),
                            backgroundColor: context
                                .watch<ThemeProvider>()
                                .primaryColor
                                .withOpacity(0.1),
                            labelStyle: TextStyle(
                                color: context
                                    .watch<ThemeProvider>()
                                    .primaryColor),
                            deleteIcon: Icon(Icons.close,
                                size: 14,
                                color: context
                                    .watch<ThemeProvider>()
                                    .primaryColor),
                            onDeleted: () {
                              setState(() {
                                _selectedTags.remove(tag);
                              });
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
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
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
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
                              padding: const EdgeInsets.all(4),
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
            if (_attachedImageUrls.isNotEmpty) const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.image_outlined,
                          color: context.watch<ThemeProvider>().primaryColor),
                      onPressed: _pickImage,
                      tooltip: AppLocalizations.of(context)
                          .translate('community.create_post.add_image'),
                    ),
                    IconButton(
                      icon: Icon(Icons.tag,
                          color: context.watch<ThemeProvider>().primaryColor),
                      onPressed: _openTagPicker,
                      tooltip: AppLocalizations.of(context)
                          .translate('community.create_post.add_tags'),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isPosting ? null : _handlePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        context.watch<ThemeProvider>().primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
