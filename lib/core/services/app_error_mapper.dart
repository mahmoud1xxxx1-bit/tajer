import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

enum TajerMessageType { success, error, warning, info, validation }

class TajerUserMessage {
  final TajerMessageType type;
  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;

  const TajerUserMessage({
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
  });

  String title(bool isAr) => isAr ? titleAr : titleEn;
  String message(bool isAr) => isAr ? messageAr : messageEn;
}

abstract final class AppErrorMapper {
  static const _fallback = TajerUserMessage(
    type: TajerMessageType.error,
    titleAr: 'تعذر إكمال العملية',
    titleEn: 'Could not complete the action',
    messageAr:
        'حدث خطأ غير متوقع. حاول مرة أخرى، وإذا استمرت المشكلة تواصل مع الدعم.',
    messageEn:
        'An unexpected error occurred. Try again, and contact support if the problem continues.',
  );

  static TajerUserMessage validation({
    required String ar,
    required String en,
  }) =>
      TajerUserMessage(
        type: TajerMessageType.validation,
        titleAr: 'تحقق من البيانات',
        titleEn: 'Check the details',
        messageAr: ar,
        messageEn: en,
      );

  static TajerUserMessage success({
    required String ar,
    required String en,
  }) =>
      TajerUserMessage(
        type: TajerMessageType.success,
        titleAr: 'تم بنجاح',
        titleEn: 'Done',
        messageAr: ar,
        messageEn: en,
      );

  static TajerUserMessage fromError(Object error, {String? domain}) {
    if (error is FirebaseAuthException) {
      return _auth(error.code, domain: domain);
    }
    if (error is FirebaseException) {
      return _firestore(error.code, domain: domain);
    }
    if (error is PlatformException) {
      return _platform(error.code, domain: domain);
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('wrong') ||
        raw.contains('invalid-credential') ||
        raw.contains('بيانات غير صحيحة')) {
      return _auth('invalid-credential', domain: domain);
    }
    if (raw.contains('disabled') ||
        raw.contains('removed') ||
        raw.contains('revoked') ||
        raw.contains('حذف') ||
        raw.contains('إيقاف')) {
      return const TajerUserMessage(
        type: TajerMessageType.error,
        titleAr: 'الحساب غير متاح',
        titleEn: 'Account unavailable',
        messageAr:
            'لا يمكن تسجيل الدخول بهذا الحساب. تحقق من بيانات الدخول أو تواصل مع التاجر.',
        messageEn:
            'This account cannot sign in. Check the credentials or contact the merchant.',
      );
    }
    if (raw.contains('permission-denied') ||
        raw.contains('permission denied')) {
      return _firestore('permission-denied', domain: domain);
    }
    if (raw.contains('failed-precondition')) {
      return _firestore('failed-precondition', domain: domain);
    }
    if (raw.contains('unavailable') || raw.contains('network')) {
      return _firestore('unavailable', domain: domain);
    }
    if (raw.contains('already') || raw.contains('open shift')) {
      return _shiftConflict();
    }
    if (raw.contains('insufficient')) {
      return const TajerUserMessage(
        type: TajerMessageType.error,
        titleAr: 'الكمية غير كافية',
        titleEn: 'Insufficient quantity',
        messageAr: 'لا توجد كمية كافية لإكمال العملية.',
        messageEn: 'There is not enough quantity to complete this action.',
      );
    }
    return _fallback;
  }

  static TajerUserMessage _auth(String code, {String? domain}) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return const TajerUserMessage(
          type: TajerMessageType.error,
          titleAr: 'بيانات الدخول غير صحيحة',
          titleEn: 'Invalid sign-in details',
          messageAr: 'تأكد من بريد التاجر ورمز الدخول ثم حاول مرة أخرى.',
          messageEn: 'Check the merchant email and PIN, then try again.',
        );
      case 'network-request-failed':
        return _firestore('unavailable', domain: domain);
      default:
        return _fallback;
    }
  }

  static TajerUserMessage _platform(String code, {String? domain}) {
    if (code.toLowerCase().contains('sign_in_canceled') ||
        code.toLowerCase().contains('cancel')) {
      return const TajerUserMessage(
        type: TajerMessageType.info,
        titleAr: 'لم يكتمل تسجيل الدخول',
        titleEn: 'Sign-in was not completed',
        messageAr: 'تم إلغاء تسجيل الدخول. يمكنك المحاولة مرة أخرى.',
        messageEn: 'Sign-in was cancelled. You can try again.',
      );
    }
    return _fallback;
  }

  static TajerUserMessage _firestore(String code, {String? domain}) {
    switch (code) {
      case 'permission-denied':
        return TajerUserMessage(
          type: TajerMessageType.error,
          titleAr: domain == 'shift' ? 'تعذر فتح الوردية' : 'ليست لديك صلاحية',
          titleEn: domain == 'shift'
              ? 'Could not start shift'
              : 'Permission required',
          messageAr:
              'لا يمكن تنفيذ هذه العملية بالحساب الحالي. تحقق من الصلاحيات والفرع المحدد.',
          messageEn:
              'This action is not allowed for the current account. Check permissions and the selected branch.',
        );
      case 'failed-precondition':
        return const TajerUserMessage(
          type: TajerMessageType.error,
          titleAr: 'الإعداد غير مكتمل',
          titleEn: 'Setup is incomplete',
          messageAr:
              'تحتاج هذه العملية إلى إعداد إضافي. حاول لاحقًا أو تواصل مع الدعم.',
          messageEn:
              'This action needs additional setup. Try later or contact support.',
        );
      case 'not-found':
        return const TajerUserMessage(
          type: TajerMessageType.error,
          titleAr: 'العنصر غير موجود',
          titleEn: 'Item not found',
          messageAr: 'تعذر العثور على البيانات المطلوبة.',
          messageEn: 'The requested data could not be found.',
        );
      case 'already-exists':
        return _shiftConflict();
      case 'aborted':
      case 'deadline-exceeded':
        return const TajerUserMessage(
          type: TajerMessageType.warning,
          titleAr: 'حاول مرة أخرى',
          titleEn: 'Try again',
          messageAr: 'لم تكتمل العملية بسبب تعارض أو بطء مؤقت. حاول مرة أخرى.',
          messageEn:
              'The action did not finish because of a temporary conflict or delay. Try again.',
        );
      case 'resource-exhausted':
        return const TajerUserMessage(
          type: TajerMessageType.warning,
          titleAr: 'الخدمة مشغولة',
          titleEn: 'Service is busy',
          messageAr: 'الخدمة مشغولة الآن. انتظر قليلًا ثم حاول مرة أخرى.',
          messageEn: 'The service is busy. Wait a moment and try again.',
        );
      case 'unavailable':
        return const TajerUserMessage(
          type: TajerMessageType.warning,
          titleAr: 'الاتصال غير متاح',
          titleEn: 'Connection unavailable',
          messageAr: 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
          messageEn: 'Check your internet connection and try again.',
        );
      default:
        return _fallback;
    }
  }

  static TajerUserMessage _shiftConflict() {
    return const TajerUserMessage(
      type: TajerMessageType.warning,
      titleAr: 'توجد وردية مفتوحة',
      titleEn: 'Shift already open',
      messageAr: 'توجد وردية مفتوحة لهذا الفرع. أغلقها قبل فتح وردية جديدة.',
      messageEn:
          'There is already an open shift for this branch. Close it before starting a new one.',
    );
  }
}
