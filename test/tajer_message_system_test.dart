import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/services/app_error_mapper.dart';

void main() {
  group('Tajer message system', () {
    test('permission denied maps to a safe user-facing message', () {
      final message = AppErrorMapper.fromError(
        Exception('[cloud_firestore/permission-denied] raw backend detail'),
        domain: 'shift',
      );

      expect(message.type, TajerMessageType.error);
      expect(message.titleEn, 'Could not start shift');
      final combined = '${message.titleEn} ${message.messageEn} '
              '${message.titleAr} ${message.messageAr}'
          .toLowerCase();
      expect(combined, isNot(contains('cloud_firestore')));
      expect(combined, isNot(contains('permission-denied')));
      expect(combined, isNot(contains('raw backend detail')));
    });

    test('auth and network failures map without exposing exception text', () {
      final invalid = AppErrorMapper.fromError(
        Exception('invalid-credential stack trace email pin details'),
      );
      final network = AppErrorMapper.fromError(
        Exception('network unavailable socket exception'),
      );

      expect(invalid.titleEn, 'Invalid sign-in details');
      expect(invalid.messageEn, isNot(contains('stack trace')));
      expect(network.titleEn, 'Connection unavailable');
      expect(network.messageEn, isNot(contains('socket exception')));
    });

    test('critical auth and shift surfaces use the centralized mapper', () {
      final startup =
          File('lib/features/authentication/presentation/startup_screen.dart')
              .readAsStringSync();
      final startShift =
          File('lib/features/shifts/presentation/start_shift_dialog.dart')
              .readAsStringSync();

      expect(startup, contains('TajerMessage.show'));
      expect(startup, contains('AppErrorMapper.fromError'));
      expect(startup, isNot(contains('replaceAll(\'Exception: \', \'\')')));
      expect(startShift, contains('TajerMessage.show'));
      expect(startShift, contains("domain: 'shift'"));
      expect(startShift, isNot(contains('Error: \$e')));
      expect(startShift, isNot(contains('SnackBar(')));
    });
  });
}
