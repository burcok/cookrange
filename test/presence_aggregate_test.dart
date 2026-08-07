import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/utils/presence_aggregate.dart';

DevicePresence _device(String id, PresenceState state) =>
    DevicePresence(deviceId: id, state: state);

void main() {
  group('PresenceAggregate.resolve', () {
    test('empty device list resolves to offline', () {
      expect(PresenceAggregate.resolve(const []), PresenceState.offline);
    });

    test('all devices offline resolves to offline', () {
      final devices = [
        _device('phone', PresenceState.offline),
        _device('tablet', PresenceState.offline),
        _device('web', PresenceState.offline),
      ];
      expect(PresenceAggregate.resolve(devices), PresenceState.offline);
    });

    test('one online among several resolves to online', () {
      final devices = [
        _device('phone', PresenceState.away),
        _device('tablet', PresenceState.online),
        _device('web', PresenceState.offline),
      ];
      expect(PresenceAggregate.resolve(devices), PresenceState.online);
    });

    test('only away devices (no online) resolves to away', () {
      final devices = [
        _device('phone', PresenceState.away),
        _device('tablet', PresenceState.offline),
      ];
      expect(PresenceAggregate.resolve(devices), PresenceState.away);
    });

    test('a single online device resolves to online', () {
      expect(
        PresenceAggregate.resolve([_device('phone', PresenceState.online)]),
        PresenceState.online,
      );
    });
  });
}
