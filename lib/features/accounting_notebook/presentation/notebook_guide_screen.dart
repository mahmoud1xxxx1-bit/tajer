import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/glass_card.dart';
import '../../../l10n/app_localizations.dart';
import '../utils/notebook_terminology.dart';

class NotebookGuideScreen extends StatelessWidget {
  const NotebookGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.notebookGuide,
          style: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.menu_book,
                      size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.notebookWelcomeTitle,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.notebookWelcomeDesc,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec1Title,
              icon: Icons.account_balance_wallet,
              content: l10n.notebookGuideSec1Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec2Title,
              icon: Icons.book,
              content: l10n.notebookGuideSec2Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec3Title,
              icon: Icons.account_balance,
              content: l10n.notebookGuideSec3Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec4Title,
              icon: Icons.category,
              content: l10n.notebookGuideSec4Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec5Title,
              icon: Icons.arrow_downward,
              content: l10n.notebookGuideSec5Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec6Title,
              icon: Icons.arrow_upward,
              content: l10n.notebookGuideSec6Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec7Title,
              icon: Icons.swap_horiz,
              content: l10n.notebookGuideSec7Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec8Title,
              icon: Icons.people,
              content: l10n.notebookGuideSec8Desc),
          _buildGuideStep(context, isAr,
              title: isAr
                  ? '٩. ${NotebookTerminology.accountsReceivable(context)}'
                  : '9. ${NotebookTerminology.accountsReceivable(context)}',
              icon: Icons.person_add,
              content: l10n.notebookReceivableHint),
          _buildGuideStep(context, isAr,
              title: isAr
                  ? '١٠. ${NotebookTerminology.accountsPayable(context)}'
                  : '10. ${NotebookTerminology.accountsPayable(context)}',
              icon: Icons.person_remove,
              content: l10n.notebookPayableHint),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec11Title,
              icon: Icons.list_alt,
              content: l10n.notebookGuideSec11Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec12Title,
              icon: Icons.bar_chart,
              content: l10n.notebookGuideSec12Desc),
          _buildGuideStep(context, isAr,
              title: l10n.notebookGuideSec13Title,
              icon: Icons.archive,
              content: l10n.notebookGuideSec13Desc),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGuideStep(
    BuildContext context,
    bool isAr, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: ExpansionTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  content,
                  style: const TextStyle(
                      fontFamily: 'Tajawal', fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
