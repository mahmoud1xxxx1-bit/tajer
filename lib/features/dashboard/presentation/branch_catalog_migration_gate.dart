import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BranchCatalogMigrationGate extends StatelessWidget {
  final AsyncValue<void> state;
  final VoidCallback onRetry;
  final WidgetBuilder readyBuilder;

  const BranchCatalogMigrationGate({
    super.key,
    required this.state,
    required this.onRetry,
    required this.readyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const _MigrationSetupScaffold(isError: false);
    }
    if (state.hasError) {
      return _MigrationSetupScaffold(isError: true, onRetry: onRetry);
    }
    return KeyedSubtree(
      key: const Key('branch-catalog-migration-ready'),
      child: readyBuilder(context),
    );
  }
}

class _MigrationSetupScaffold extends StatelessWidget {
  final bool isError;
  final VoidCallback? onRetry;

  const _MigrationSetupScaffold({
    required this.isError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = Theme.of(context).colorScheme;
    final message = isError
        ? (isArabic
            ? '\u062a\u0639\u0630\u0631 \u0625\u0643\u0645\u0627\u0644 \u062a\u0647\u064a\u0626\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0641\u0631\u0648\u0639. \u0644\u0645 \u064a\u062a\u0645 \u062a\u063a\u064a\u064a\u0631 \u0628\u064a\u0627\u0646\u0627\u062a\u0643. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.'
            : 'Branch data setup could not be completed. Your data was not changed. Try again.')
        : (isArabic
            ? '\u062c\u0627\u0631\u064d \u062a\u0647\u064a\u0626\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0641\u0631\u0648\u0639. \u0642\u062f \u064a\u0633\u062a\u063a\u0631\u0642 \u0630\u0644\u0643 \u0644\u062d\u0638\u0627\u062a.'
            : 'Preparing branch data. This may take a few moments.');

    return Scaffold(
      key: Key(isError
          ? 'branch-catalog-migration-error'
          : 'branch-catalog-migration-loading'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError
                        ? Icons.cloud_off_outlined
                        : Icons.storefront_outlined,
                    size: 48,
                    color: isError ? colors.error : colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tajer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          fontFamily: 'Tajawal',
                        ),
                  ),
                  const SizedBox(height: 20),
                  if (isError)
                    FilledButton.icon(
                      key: const Key('branch-catalog-migration-retry'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        isArabic
                            ? '\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629'
                            : 'Retry',
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
