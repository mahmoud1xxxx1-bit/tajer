import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/main.dart';

void main() {
  test('Tajer app widget is the application entry widget', () {
    expect(const TajerApp(), isA<TajerApp>());
  });
}
