/// Chat Upgrade Phase 2 — one RTDB `/presence/{uid}/{deviceId}` node's
/// decoded state. Pure data, no Firebase types, so it can flow straight into
/// [PresenceAggregate.resolve] with zero Firebase dependency — mirrors
/// `message_status.dart`'s Firebase-free precedent (`chat_list_filter.dart`
/// for the filter/sort shape, `message_status.dart` for the "resolve a pure
/// enum from already-loaded state" shape specifically).
enum PresenceState { online, away, offline }

/// One device's last-known presence, as decoded from
/// `/presence/{uid}/{deviceId}` by whoever reads the RTDB node (client-side
/// `PresenceService`, or `functions/chat_presence.js`'s JS-side
/// reimplementation of this same precedence rule — see that file's header
/// comment for why the rule isn't shared code across Dart/JS).
class DevicePresence {
  final String deviceId;
  final PresenceState state;
  const DevicePresence({required this.deviceId, required this.state});
}

/// Aggregates every device a user has open into ONE user-level
/// [PresenceState] — the "is this user online" answer `UserModel.isOnline`
/// ultimately mirrors. Kept as a separate pure util (rather than inlined in
/// `PresenceService`) specifically so it's unit-testable without any
/// Firebase mocking, per `CLAUDE.md` §8 ("new pure logic gets a unit test") —
/// see `test/presence_aggregate_test.dart`.
class PresenceAggregate {
  const PresenceAggregate._();

  /// Precedence is deliberately `online > away > offline`: ANY ONE device
  /// online is enough for the aggregate to read online. This is what makes
  /// per-device presence correct for a real multi-device user — a phone
  /// backgrounded to `away` while a tablet sits open and active must still
  /// show the user as online overall, not average out to "away".
  ///
  /// An empty device list (no session has ever registered, or every device
  /// node has aged out / been swept) resolves to `offline` — there is no
  /// device to be online.
  static PresenceState resolve(List<DevicePresence> devices) {
    if (devices.isEmpty) return PresenceState.offline;
    if (devices.any((d) => d.state == PresenceState.online)) {
      return PresenceState.online;
    }
    if (devices.any((d) => d.state == PresenceState.away)) {
      return PresenceState.away;
    }
    return PresenceState.offline;
  }
}
