class DiscountValidator {
  static bool isValid({
    required String? type,
    required String text,
    required double cartSubtotal,
  }) {
    if (type == null) return true;
    final valText = text.trim();
    final val = valText.isEmpty ? 0.0 : double.tryParse(valText);
    
    if (val == null || val.isNaN || val.isInfinite || val < 0) return false;
    
    if (type == 'percentage' && val > 100) return false;
    if (type == 'amount' && val > cartSubtotal) return false;
    
    return true;
  }
}
