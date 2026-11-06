import 'package:drift/isolate.dart';
import 'package:drift/native.dart';

class DatabaseBusyException implements Exception {
  const DatabaseBusyException(this.cause);
  final Object cause;
  @override
  String toString() => 'Database is busy. Try again.';
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// Retry only complete database transactions, never an external side effect.
class SqliteWritePolicy {
  const SqliteWritePolicy({this.attempts = 10, this.wait = _wait})
    : assert(attempts > 0);
  final int attempts;
  final Future<void> Function(Duration) wait;

  Future<T> run<T>(
    Future<T> Function() action, {
    bool Function()? mayRetry,
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } catch (error) {
        final cause = error is DriftRemoteException ? error.remoteCause : error;
        if (cause is! SqliteException ||
            !{5, 6}.contains(cause.extendedResultCode & 0xff)) {
          rethrow;
        }
        // An authorization commit can fail after handoff. Retrying that
        // transaction would repeat the external request.
        if (mayRetry != null && !mayRetry()) rethrow;
        if (attempt >= attempts) throw DatabaseBusyException(error);
        await wait(Duration(milliseconds: 20 * attempt));
      }
    }
  }
}
