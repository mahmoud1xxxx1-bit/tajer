import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/providers/store_profile_provider.dart';

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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final bytes = await File(path).readAsBytes();
          // Optional: resize image if it's too large, but for now just encode
          setState(() {
            _logoBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في اختيار الصورة', style: TextStyle(fontFamily: 'Tajawal'))));
    }
  }

  void _save() {
    final profile = StoreProfile(
      storeName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      defaultTaxPercentage: double.tryParse(_taxController.text.trim()),
      vatNumber: _vatNumberController.text.trim().isEmpty ? null : _vatNumberController.text.trim(),
      crNumber: _crNumberController.text.trim().isEmpty ? null : _crNumberController.text.trim(),
      logoBase64: _logoBase64,
    );
    ref.read(storeProfileProvider.notifier).updateProfile(profile);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ بنجاح', style: TextStyle(fontFamily: 'Tajawal'))));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('هوية المتجر', style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
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
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(imageBytes, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('شعار المتجر', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
              ),
              if (_logoBase64.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _logoBase64 = ''),
                  child: const Text('إزالة الشعار', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المتجر',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف المتجر',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _taxController,
                decoration: const InputDecoration(
                  labelText: 'نسبة الضريبة الافتراضية (%)',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                  helperText: 'إذا قمت بتعيين نسبة هنا، سيتم تطبيقها تلقائياً على كل الفواتير المطبوعة. اترك الحقل فارغاً إذا كنت تريد إدخال النسبة يدوياً في كل مرة.',
                  helperMaxLines: 3,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              
              // ZATCA Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'تفعيل الفاتورة الضريبية المبسطة (الرسمية)',
                            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'بإدخالك "الرقم الضريبي"، سيتم تحويل الفواتير تلقائياً إلى "فواتير ضريبية" رسمية.\n(ملاحظة: للتجار في السعودية، الفاتورة ستكون متوافقة كلياً مع متطلبات هيئة الزكاة والضريبة ZATCA ومزودة بالـ QR Code المشفر).',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _vatNumberController,
                      decoration: const InputDecoration(
                        labelText: 'الرقم الضريبي (VAT Number)',
                        prefixIcon: Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(),
                        helperText: 'للتجار في السعودية: 15 رقماً. في الدول الأخرى: أدخل الرقم المعتمد لديكم (يقبل حروف وأرقام).',
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _crNumberController,
                      decoration: const InputDecoration(
                        labelText: 'رقم السجل التجاري (CR Number) - اختياري',
                        prefixIcon: Icon(Icons.assignment),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
