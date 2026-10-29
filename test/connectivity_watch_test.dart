import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:background_downloader/src/connectivity_watch.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stream that fails as connectivity_plus does on Linux without
/// NetworkManager: the error is thrown in an async onListen, so it goes to the
/// zone that called listen and not to onError.
Stream<List<ConnectivityResult>> failingOnListen() {
  late StreamController<List<ConnectivityResult>> controller;
  controller = StreamController.broadcast(
    onListen: () async {
      await Future<void>.delayed(Duration.zero);
      throw Exception('org.freedesktop.DBus.Error.ServiceUnknown');
    },
  );
  return controller.stream;
}

/// Storage that is ready at once: the default storage needs path_provider
/// on a background isolate, which a host test does not have.
class _NoStorage implements PersistentStorage {
  @override
  Future<void> initialize() => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('watchConnectivity', () {
    test('a failed check reports unavailable and does not listen', () async {
      final results = <List<ConnectivityResult>>[];
      final errors = <Object>[];
      var listened = false;
      final subscription = await watchConnectivity(
        check: () async => throw Exception('no NetworkManager'),
        changes: () {
          listened = true;
          return failingOnListen();
        },
        onResults: results.add,
        onUnavailable: errors.add,
      );
      await settle();
      expect(subscription, isNull);
      expect(listened, isFalse);
      expect(results, isEmpty);
      expect(errors, hasLength(1));
    });

    test('an error in the stream setup is not unhandled', () async {
      final results = <List<ConnectivityResult>>[];
      final errors = <Object>[];
      final subscription = await watchConnectivity(
        check: () async => [ConnectivityResult.ethernet],
        changes: failingOnListen,
        onResults: results.add,
        onUnavailable: errors.add,
      );
      await settle();
      expect(subscription, isNotNull);
      expect(results, [
        [ConnectivityResult.ethernet],
      ]);
      expect(errors, hasLength(1));
    });

    test('an error event on the stream reports unavailable once', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      final results = <List<ConnectivityResult>>[];
      final errors = <Object>[];
      await watchConnectivity(
        check: () async => [ConnectivityResult.wifi],
        changes: () => controller.stream,
        onResults: results.add,
        onUnavailable: errors.add,
      );
      controller.addError(Exception('first'));
      controller.addError(Exception('second'));
      await settle();
      expect(errors, hasLength(1));
      expect(results, hasLength(1));
      await controller.close();
    });

    test('changes are delivered after the check', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      final results = <List<ConnectivityResult>>[];
      final errors = <Object>[];
      final subscription = await watchConnectivity(
        check: () async => [ConnectivityResult.none],
        changes: () => controller.stream,
        onResults: results.add,
        onUnavailable: errors.add,
      );
      controller.add([ConnectivityResult.wifi]);
      await settle();
      expect(results, [
        [ConnectivityResult.none],
        [ConnectivityResult.wifi],
      ]);
      expect(errors, isEmpty);
      await subscription!.cancel();
      await controller.close();
    });
  });

  test(
    'FileDownloader assumes Wi-Fi when connectivity is unavailable',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async => '/tmp',
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (MethodCall call) async => throw PlatformException(code: 'unavailable'),
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.bbflight.background_downloader'),
        (MethodCall call) async => switch (call.method) {
          'reset' => 0,
          'platformVersion' => '34',
          'allTasks' => <dynamic>[],
          'popResumeData' || 'popStatusUpdates' || 'popProgressUpdates' => '{}',
          _ => null,
        },
      );

      final downloader = FileDownloader(persistentStorage: _NoStorage());
      expect(downloader.isWiFi, isFalse);
      await downloader.ready;
      await settle();
      expect(downloader.isConnected, isTrue);
      expect(downloader.isWiFi, isTrue);
    },
  );
}
