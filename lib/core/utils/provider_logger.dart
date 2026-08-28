import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

class ProviderLogger extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderBase provider,
    Object? value,
    ProviderContainer container,
  ) {
    AppLogger.d('Provider added: ${provider.name ?? provider.runtimeType} | value: $value');
  }

  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    AppLogger.i('Provider updated: ${provider.name ?? provider.runtimeType}\n'
        '  Previous: $previousValue\n'
        '  New: $newValue');
  }

  @override
  void didDisposeProvider(
    ProviderBase provider,
    ProviderContainer container,
  ) {
    AppLogger.d('Provider disposed: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void providerDidFail(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    AppLogger.e('Provider failed: ${provider.name ?? provider.runtimeType}', error, stackTrace);
  }
}
