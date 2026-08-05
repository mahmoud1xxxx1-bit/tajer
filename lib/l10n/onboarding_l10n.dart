class OnboardingL10n {
  static const ar = {
    'setupChecklistTitle': 'جهز متجرك للبيع',
    'setupStep1': 'أسس متجرك (أضف تصنيف)',
    'setupStep2': 'تجهيز الرفوف (أضف منتج)',
    'setupStep3': 'استلام العهدة (افتح وردية)',
    'setupStep4': 'أول غيث (أنشئ مبيعة)',
    'setupCompleted': 'أنت جاهز تماماً للبيع! 🎉',
  };
  static const en = {
    'setupChecklistTitle': 'Get Your Store Ready',
    'setupStep1': 'Setup Store (Add Category)',
    'setupStep2': 'Stock Shelves (Add Product)',
    'setupStep3': 'Take Shift (Open Shift)',
    'setupStep4': 'First Sale (Make Sale)',
    'setupCompleted': 'You are fully ready to sell! 🎉',
  };
  
  static String get(String key, bool isAr) {
    return isAr ? (ar[key] ?? key) : (en[key] ?? key);
  }
}
