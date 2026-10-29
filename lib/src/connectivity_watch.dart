import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches connectivity, and reports a missing connectivity service to
/// [onUnavailable] instead of as an unhandled error.
///
/// [check] gets the current connectivity, and [changes] gets the stream of
/// changes. [onResults] receives the result of [check] and then each change.
/// The stream is listened to only if [check] succeeds.
///
/// On Linux, connectivity_plus asks NetworkManager on the system bus. Without
/// NetworkManager, [check] throws. The stream's listener setup fails too, but
/// that error goes to the zone that called listen, not to `onError`. The
/// listen is therefore in a guarded zone, for the case that NetworkManager
/// stops between the check and the listen.
///
/// [onUnavailable] is called at most once. After it, [onResults] is not
/// called again.
Future<StreamSubscription<List<ConnectivityResult>>?> watchConnectivity({
  required Future<List<ConnectivityResult>> Function() check,
  required Stream<List<ConnectivityResult>> Function() changes,
  required void Function(List<ConnectivityResult> results) onResults,
  required void Function(Object error) onUnavailable,
}) async {
  final List<ConnectivityResult> initial;
  try {
    initial = await check();
  } catch (e) {
    onUnavailable(e);
    return null;
  }
  onResults(initial);

  final outer = Zone.current;
  StreamSubscription<List<ConnectivityResult>>? subscription;
  var available = true;
  void fail(Object error) {
    if (!available) return;
    available = false;
    unawaited(subscription?.cancel());
    onUnavailable(error);
  }

  runZonedGuarded(() {
    subscription = changes().listen(
      // Errors from onResults are not connectivity errors: they go to the
      // caller's zone, as they would without the guarded zone.
      (results) {
        if (available) outer.runUnaryGuarded(onResults, results);
      },
      onError: (Object error) => outer.runUnaryGuarded(fail, error),
    );
  }, (error, _) => outer.runUnaryGuarded(fail, error));
  return subscription;
}
