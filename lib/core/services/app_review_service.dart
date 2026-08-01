import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppReviewService {
  AppReviewService._privateConstructor();
  static final AppReviewService instance = AppReviewService._privateConstructor();

  static const String _playStoreId = 'com.allldown.tajer';
  static const String _keyHasRated = 'has_rated_app';
  static const String _keyActionCount = 'review_action_count';
  static const String _keyLastDismissed = 'review_last_dismissed_date';

  /// Open Google Play store review page directly
  Future<void> openPlayStore(BuildContext? context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);

    final Uri marketUri = Uri.parse('market://details?id=$_playStoreId');
    final Uri webUri = Uri.parse('https://play.google.com/store/apps/details?id=$_playStoreId');

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Play Store: $e');
    }
  }

  /// Gently check if it's a good time to ask for a review without annoying the merchant
  Future<void> checkAndPromptForReview(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRated = prefs.getBool(_keyHasRated) ?? false;
      if (hasRated) return;

      // Check if dismissed recently (wait at least 7 days before re-prompting)
      final lastDismissedStr = prefs.getString(_keyLastDismissed);
      if (lastDismissedStr != null) {
        final lastDismissed = DateTime.tryParse(lastDismissedStr);
        if (lastDismissed != null && DateTime.now().difference(lastDismissed).inDays < 7) {
          return;
        }
      }

      int count = prefs.getInt(_keyActionCount) ?? 0;
      count++;
      await prefs.setInt(_keyActionCount, count);

      // Prompt on the 4th interaction/open, then every 15 interactions if not explicitly rated
      if (count == 4 || (count > 4 && count % 15 == 0)) {
        if (context.mounted) {
          await Future.delayed(const Duration(seconds: 2));
          if (context.mounted) {
            showReviewDialog(context, fromSettings: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in AppReviewService: $e');
    }
  }

  /// Displays an elegant, polite, and warm bilingual review modal
  void showReviewDialog(BuildContext context, {bool fromSettings = false}) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star Icon / Header Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Warm Title
                Text(
                  isAr ? 'نسعد بوجودك معنا في تاجر! 🌟' : 'We love having you in Tajer! 🌟',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Polite Body Copy
                Text(
                  isAr
                      ? 'رأيك يهمنا جداً ويمنحنا الحافز المستمر لتطوير التطبيق وتقديم أفضل أدوات إدارة لمتجرك وتجارتك. هل تتفضل بدقيقة لدعمنا بتقييم 5 نجوم على متجر جوجل؟'
                      : 'Your feedback inspires us to keep improving Tajer and building the best tools for your business. Would you take a moment to support us with a 5-star review?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Rate Now Button (Primary)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      openPlayStore(context);
                    },
                    icon: const Icon(Icons.star, color: Colors.white),
                    label: Text(
                      isAr ? 'تقييم التطبيق الآن (5 نجوم)' : 'Rate Now (5 Stars)',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                
                // Secondary / Remind Later Option (Only if shown automatically)
                if (!fromSettings) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(_keyLastDismissed, DateTime.now().toIso8601String());
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: Text(
                        isAr ? 'تذكيري بوقت لاحق' : 'Remind me later',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Dismiss Option
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    if (!fromSettings) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_keyHasRated, true); // Never ask again if declined
                    }
                  },
                  child: Text(
                    isAr ? (fromSettings ? 'إغلاق' : 'لا شكرًا، لست مهتمًا الآن') : (fromSettings ? 'Close' : 'No thanks, I\'m not interested'),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
