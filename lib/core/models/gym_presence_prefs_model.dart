/// `users/{uid}/private/presence_prefs` — Faz 1 §1.4.
///
/// [gymTrackingEnabled] is per-gym: a member can belong to several gyms (up
/// to the 3-gym / 20-region cap, §1.2) but only want background auto
/// check-in at one of them. Absent from the map (or the whole doc missing)
/// means off — granting [ConsentPurpose.gymPresence] only unlocks the
/// *feature*; each gym still starts untracked (K2: varsayılan kapalı).
///
/// The rest cover Faz 1.7's three-toggle "friend at gym" notification spec:
/// [notifyFriendsEnabled] is toggle (a) — never let my friends be notified
/// when I arrive (checked on the ARRIVING user, server-side, before any fan-
/// out even starts). [mutedFriendUids] is toggle (c) — a specific friend
/// whose arrivals I don't want to hear about (checked on the RECEIVING
/// user). Toggle (b) — "never receive these at all" — is a type-level mute
/// and lives on `NotificationPreferencesService`'s `presence` group instead,
/// since it's identical in shape to every other notification mute.
class GymPresencePrefsModel {
  final Map<String, bool> gymTrackingEnabled;
  final bool notifyFriendsEnabled;
  final List<String> mutedFriendUids;

  const GymPresencePrefsModel({
    this.gymTrackingEnabled = const {},
    this.notifyFriendsEnabled = false,
    this.mutedFriendUids = const [],
  });

  static const empty = GymPresencePrefsModel();

  factory GymPresencePrefsModel.fromFirestore(Map<String, dynamic>? d) {
    if (d == null) return empty;
    final rawMap = d['gym_tracking_enabled'];
    return GymPresencePrefsModel(
      gymTrackingEnabled: rawMap is Map
          ? rawMap.map((k, v) => MapEntry(k.toString(), v == true))
          : const {},
      notifyFriendsEnabled: d['notify_friends_enabled'] as bool? ?? false,
      mutedFriendUids: List<String>.from(d['muted_friend_uids'] as List? ?? []),
    );
  }

  bool trackingEnabledFor(String gymId) => gymTrackingEnabled[gymId] ?? false;
  bool hasMutedFriend(String friendUid) => mutedFriendUids.contains(friendUid);
}
