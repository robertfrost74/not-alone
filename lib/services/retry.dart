typedef RetryCondition = bool Function(Object error);

Future<T> withRetry<T>(
  Future<T> Function() action, {
  int retries = 2,
  Duration baseDelay = const Duration(milliseconds: 300),
  RetryCondition? shouldRetry,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await action();
    } catch (e) {
      final allowRetry = shouldRetry?.call(e) ?? false;
      if (attempt >= retries || !allowRetry) rethrow;
      final delay = baseDelay * (1 << attempt);
      await Future<void>.delayed(delay);
      attempt += 1;
    }
  }
}
