void main() {
  print('--- TESTING DART FLOAT PRECISION ---');
  print('0.1 + 0.2 = ${0.1 + 0.2}');
  print('100 - (100 / 1.15) = ${100 - (100 / 1.15)}');
  print('VAT Rounding test: ${(100 - (100 / 1.15)).toStringAsFixed(2)}');
}
