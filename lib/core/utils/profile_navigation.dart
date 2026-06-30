import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../widgets/ds/ds.dart';
import '../../screens/profile/profile_screen.dart';

/// Opens a user's profile from anywhere a name/avatar is shown.
///
/// Pass a full [user] when available (friend lists, search results) or a
/// [userId] when only an id is on hand (post authors, leaderboard rows). Tapping
/// your own avatar opens your own (private) profile view.
///
/// No-ops if neither identifier is provided or the id is empty.
void openUserProfile(
  BuildContext context, {
  String? userId,
  UserModel? user,
}) {
  final id = user?.uid ?? userId;
  if (id == null || id.trim().isEmpty) return;

  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  // Viewing self → open own profile in private/editable mode.
  if (currentUid != null && id == currentUid) {
    Navigator.push(context, AppTransitions.slideUp(const ProfileScreen()));
    return;
  }

  Navigator.push(
    context,
    AppTransitions.slideUp(
      user != null ? ProfileScreen(viewUser: user) : ProfileScreen(userId: id),
    ),
  );
}

/// Wraps [child] so tapping it opens the given user's profile.
class ProfileLink extends StatelessWidget {
  final Widget child;
  final String? userId;
  final UserModel? user;
  final HitTestBehavior behavior;

  const ProfileLink({
    super.key,
    required this.child,
    this.userId,
    this.user,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: () => openUserProfile(context, userId: userId, user: user),
      child: child,
    );
  }
}
