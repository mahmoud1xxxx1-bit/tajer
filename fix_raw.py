file = 'lib/features/products/presentation/raw_materials_screen.dart'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

getter = '  AppLocalizations get l10n => AppLocalizations.of(context)!;'
target = 'class _RawMaterialsScreenState extends ConsumerState<RawMaterialsScreen> {'
if getter not in content:
    content = content.replace(target, target + '\n' + getter)
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print('raw_materials_screen fixed!')
