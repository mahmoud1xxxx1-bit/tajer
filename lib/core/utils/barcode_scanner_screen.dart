import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();

  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (mounted) setState(() => _hasPermission = true);
    } else {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('إذن الكاميرا مطلوب', style: TextStyle(fontFamily: 'Tajawal')),
            content: const Text('يرجى السماح للتطبيق باستخدام الكاميرا لمسح الباركود.', style: TextStyle(fontFamily: 'Tajawal')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('رجوع', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('فتح الإعدادات', style: TextStyle(fontFamily: 'Tajawal')),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text25, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: _hasPermission 
        ? MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final barcodeValue = barcodes.first.rawValue!;
                cameraController.stop();
                Navigator.of(context).pop(barcodeValue);
              }
            },
          )
        : const Center(child: CircularProgressIndicator()),
    );
  }
}
