import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/discount_validator.dart';

void main() {
  group('Discount Validator Tests (Gate 10)', () {
    const double cartSubtotal = 100.0;

    test('Valid normal percentage passes', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: '10', cartSubtotal: cartSubtotal),
          isTrue);
    });

    test('Valid normal amount passes', () {
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: '20', cartSubtotal: cartSubtotal),
          isTrue);
    });

    test('Zero passes', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: '0', cartSubtotal: cartSubtotal),
          isTrue);
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: '0', cartSubtotal: cartSubtotal),
          isTrue);
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: '', cartSubtotal: cartSubtotal),
          isTrue); // empty is 0
    });

    test('Negative percentage is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: '-5', cartSubtotal: cartSubtotal),
          isFalse);
    });

    test('Percentage > 100 is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: '105', cartSubtotal: cartSubtotal),
          isFalse);
    });

    test('Negative fixed amount is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: '-10', cartSubtotal: cartSubtotal),
          isFalse);
    });

    test('Fixed amount > subtotal is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: '150', cartSubtotal: cartSubtotal),
          isFalse);
    });

    test('NaN is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: 'NaN', cartSubtotal: cartSubtotal),
          isFalse);
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: 'NaN', cartSubtotal: cartSubtotal),
          isFalse);
    });

    test('+Infinity is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: 'Infinity', cartSubtotal: cartSubtotal),
          isFalse);
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: 'Infinity', cartSubtotal: cartSubtotal),
          isFalse);
    });

    test('-Infinity is rejected', () {
      expect(
          DiscountValidator.isValid(
              type: 'percentage', text: '-Infinity', cartSubtotal: cartSubtotal),
          isFalse);
      expect(
          DiscountValidator.isValid(
              type: 'amount', text: '-Infinity', cartSubtotal: cartSubtotal),
          isFalse);
    });
  });
}
