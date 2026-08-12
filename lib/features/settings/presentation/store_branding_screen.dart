import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../../../core/theme/glass_card.dart';

class StoreBrandingScreen extends ConsumerStatefulWidget {
  const StoreBrandingScreen({super.key});

  @override
  ConsumerState<StoreBrandingScreen> createState() => _StoreBrandingScreenState();
}

class _StoreBrandingScreenState extends ConsumerState<StoreBrandingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _crNumberController = TextEditingController();
  String _logoBase64 = '';
  bool _isInit = false;
  bool _defaultIsTaxInclusive = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    _vatNumberController.dispose();
    _crNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final bytes = await File(path).readAsBytes();
          setState(() {
            _logoBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.brandingErrorPickingImage, style: const TextStyle(fontFamily: 'Tajawal'))));
      }
    }
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final profile = StoreProfile(
      storeName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      defaultTaxPercentage: double.tryParse(_taxController.text.trim()),
      defaultIsTaxInclusive: _defaultIsTaxInclusive,
      vatNumber: _vatNumberController.text.trim().isEmpty ? null : _vatNumberController.text.trim(),
      crNumber: _crNumberController.text.trim().isEmpty ? null : _crNumberController.text.trim(),
      logoBase64: _logoBase64,
    );
    ref.read(storeProfileProvider.notifier).updateProfile(profile);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.brandingSavedSuccess, style: const TextStyle(fontFamily: 'Tajawal'))));
    Navigator.pop(context);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Tajawal'),
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          helperText: helperText,
          helperMaxLines: 3,
          helperStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeProfileProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsStoreBranding, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l10n.brandingSave, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: state.when(
        data: (profile) {
          if (!_isInit) {
            _nameController.text = profile.storeName;
            _phoneController.text = profile.phone;
            _addressController.text = profile.address;
            _taxController.text = profile.defaultTaxPercentage != null ? profile.defaultTaxPercentage.toString() : '';
            _vatNumberController.text = profile.vatNumber ?? '';
            _crNumberController.text = profile.crNumber ?? '';
            _defaultIsTaxInclusive = profile.defaultIsTaxInclusive;
            _logoBase64 = profile.logoBase64;
            _isInit = true;
          }

          Uint8List? imageBytes;
          if (_logoBase64.isNotEmpty) {
            try {
              imageBytes = base64Decode(_logoBase64);
            } catch (e) {
              // Ignore invalid base64
            }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              GlassCard(
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Image.memory(imageBytes, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_rounded, size: 36, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
                                      const SizedBox(height: 8),
                                      Text(l10n.brandingSelectLogo, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8))),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      if (_logoBase64.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: () => setState(() => _logoBase64 = ''),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: Text(l10n.brandingRemoveLogo, style: const TextStyle(fontFamily: 'Tajawal')),
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _nameController,
                        label: l10n.brandingStoreName,
                        icon: Icons.store_rounded,
                      ),
                      _buildTextField(
                        controller: _phoneController,
                        label: l10n.brandingStorePhone,
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildTextField(
                        controller: _addressController,
                        label: l10n.brandingStoreAddress,
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 12, bottom: 12),
                child: Text(
                  l10n.brandingTaxSettings,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              GlassCard(
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _taxController,
                        label: l10n.brandingDefaultTax,
                        icon: Icons.percent_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        helperText: l10n.brandingDefaultTaxHelper,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                        ),
                        child: SwitchListTile(
                          title: Text(l10n.brandingTaxInclusive, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(l10n.brandingTaxInclusiveHelper, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          value: _defaultIsTaxInclusive,
                          onChanged: (val) => setState(() => _defaultIsTaxInclusive = val),
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // ZATCA Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, color: Colors.blue.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.brandingZatcaTitle,
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.brandingZatcaDesc,
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, height: 1.6, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _vatNumberController,
                      label: l10n.brandingVatNumber,
                      icon: Icons.confirmation_number_rounded,
                      keyboardType: TextInputType.text,
                      helperText: l10n.brandingVatHelper,
                    ),
                    _buildTextField(
                      controller: _crNumberController,
                      label: l10n.brandingCrNumber,
                      icon: Icons.assignment_rounded,
                      keyboardType: TextInputType.number,
                      helperText: l10n.brandingCrHelper,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.error}: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
      ),
    );
  }
}
