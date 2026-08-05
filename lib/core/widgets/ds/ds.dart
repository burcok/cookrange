/// Cookrange Design System — barrel export.
///
/// Import everything design-system with a single line:
/// ```dart
/// import 'package:cookrange/core/widgets/ds/ds.dart';
/// ```
/// Tokens + components in one place. Build the component once, reuse everywhere
/// (Rule R7). See `CLAUDE.md` → Global Engineering Rules.
library;

export '../../theme/app_dimensions.dart';
export '../../theme/app_gradients.dart';
export '../../theme/app_palette.dart';
export '../../theme/app_typography.dart';
export '../../utils/accessibility_utils.dart';
export 'app_avatar.dart';
export 'app_button.dart';
export 'app_selectors.dart';
export 'app_calorie_ring.dart';
export 'app_card.dart';
export 'app_filter_bar.dart';
export 'app_sheet.dart';
export 'app_shimmer.dart';
export 'app_snackbar.dart';
export 'app_state_views.dart';
export 'app_text_field.dart';
export 'app_transitions.dart';
export 'permission_primer.dart';

// Faz 2 §2.2 — chat components.
export 'chat/app_date_separator.dart';
export 'chat/app_media_grid.dart';
export 'chat/app_message_bubble.dart';
export 'chat/app_message_composer.dart';
export 'chat/app_message_context_menu.dart';
export 'chat/app_pinned_banner.dart';
export 'chat/app_reaction_bar.dart';
export 'chat/app_reply_preview.dart';
export 'chat/app_typing_indicator.dart';
export 'chat/app_unread_divider.dart';
