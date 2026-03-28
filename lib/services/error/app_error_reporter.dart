import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../auth/auth_token_store.dart';
import '../logging_service.dart';

class AppErrorReporter {
  AppErrorReporter._();

  static final AppErrorReporter instance = AppErrorReporter._();

  final LoggingService _logger = LoggingService();
  final Queue<_PendingError> _pending = Queue<_PendingError>();

  bool _handlersAttached = false;
  bool _flushing = false;

  void attachGlobalHandlers() {
    if (_handlersAttached) return;
    _handlersAttached = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        reportException(
          service: "Flutter",
          operation: "FlutterError.onError",
          error: details.exception,
          stackTrace: details.stack,
          payload: {
            if (details.library != null) "library": details.library,
            if (details.context != null) "context": details.context.toString(),
            if (details.exceptionAsString().isNotEmpty)
              "exception": details.exceptionAsString(),
          },
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        reportException(
          service: "Dart",
          operation: "PlatformDispatcher.onError",
          error: error,
          stackTrace: stack,
        ),
      );
      return true;
    };
  }

  Future<void> reportException({
    required String service,
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
  }) async {
    await reportMessage(
      service: service,
      operation: operation,
      message: error.toString(),
      stackTrace: stackTrace?.toString(),
      payload: payload,
    );
  }

  Future<void> reportMessage({
    required String service,
    required String operation,
    required String message,
    String? stackTrace,
    Map<String, dynamic>? payload,
  }) async {
    final entry = _PendingError(
      service: _truncate(service, 120),
      operation: _truncate(operation, 120),
      message: _truncate(message, 2000),
      stackTrace: stackTrace == null ? null : _truncate(stackTrace, 8000),
      payload: payload == null ? null : _sanitizePayload(payload),
    );

    if (!_canSendImmediately) {
      _enqueue(entry);
      return;
    }

    await _send(entry);
  }

  Future<void> flushPending() async {
    if (_flushing || _pending.isEmpty || !_canSendImmediately) return;
    _flushing = true;
    try {
      while (_pending.isNotEmpty && _canSendImmediately) {
        final entry = _pending.removeFirst();
        await _send(entry);
      }
    } finally {
      _flushing = false;
    }
  }

  bool get _canSendImmediately {
    final token = AuthTokenStore.token?.trim();
    return token != null && token.isNotEmpty;
  }

  void _enqueue(_PendingError entry) {
    const maxPending = 80;
    while (_pending.length >= maxPending) {
      _pending.removeFirst();
    }
    _pending.add(entry);
  }

  Future<void> _send(_PendingError entry) async {
    try {
      await _logger.logError(
        service: entry.service,
        operation: entry.operation,
        message: entry.message,
        stackTrace: entry.stackTrace,
        payload: entry.payload,
      );
    } catch (_) {
      // Logging must never interfere with the app.
    }
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final result = <String, dynamic>{};
    payload.forEach((key, value) {
      result[key.toString()] = _sanitizeValue(value);
    });
    return result;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;
    if (value is String ||
        value is num ||
        value is bool ||
        value is Map ||
        value is List) {
      return value;
    }
    return value.toString();
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}

class _PendingError {
  final String service;
  final String operation;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic>? payload;

  const _PendingError({
    required this.service,
    required this.operation,
    required this.message,
    required this.stackTrace,
    required this.payload,
  });
}
