import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device currently has a usable network interface.
///
/// This is a hint, not a guarantee: the plugin reports interfaces, not
/// reachability, so a real request can still fail while this says `true`.
/// That is why [mapAppError] also produces an "offline" state.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// `true` when at least one non-`none` interface is up.
  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Emits the current state immediately, then on every change.
  Stream<bool> watch() async* {
    yield _online(await _connectivity.checkConnectivity());
    yield* _connectivity.onConnectivityChanged.map(_online);
  }

  Future<bool> isOnline() async =>
      _online(await _connectivity.checkConnectivity());
}
