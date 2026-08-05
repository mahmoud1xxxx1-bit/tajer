import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/services/printer_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _device;
  bool _connected = false;
  String _message = 'لم يتم الاتصال بأي طابعة';
  String _paperSize = '58mm';

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    List<BluetoothInfo> devices = [];
    try {
      devices = await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      _message = "خطأ في البحث عن الأجهزة: $e";
    }

    if (!mounted) return;
    setState(() {
      _devices = devices;
      _connected = isConnected;
    });

    final prefs = await SharedPreferences.getInstance();
    final savedDeviceMac = prefs.getString('default_printer_mac');
    final savedPaperSize = prefs.getString('printer_paper_size') ?? '58mm';

    if (savedDeviceMac != null) {
      setState(() {
        _device = _devices.firstWhere(
          (d) => d.macAdress == savedDeviceMac,
          orElse: () => _devices.first,
        );
      });
    }

    setState(() {
      _paperSize = savedPaperSize;
    });
  }

  Future<void> _updatePaperSize(String? size) async {
    if (size == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_paper_size', size);
    setState(() => _paperSize = size);
  }

  Future<void> _connect() async {
    if (_device != null) {
      setState(() => _message = "جاري الاتصال...");
      bool connected = await PrinterService.connect(_device!.macAdress);
      if (connected) {
        setState(() {
          _connected = true;
          _message = "تم الاتصال وحفظ الطابعة كافتراضية";
        });
      } else {
        setState(() => _message = "فشل الاتصال");
      }
    } else {
      setState(() => _message = "يرجى تحديد طابعة");
    }
  }

  Future<void> _disconnect() async {
    await PrinterService.disconnect();
    setState(() => _connected = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات الطابعة الحرارية', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الأجهزة المقترنة (بلوتوث)', style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            DropdownButton<BluetoothInfo>(
              items: _devices.map((device) => DropdownMenuItem(
                child: Text(device.name),
                value: device,
              )).toList(),
              onChanged: (value) => setState(() => _device = value),
              value: _device,
              hint: const Text('اختر الطابعة', style: TextStyle(fontFamily: 'Tajawal')),
              isExpanded: true,
            ),
            const SizedBox(height: 24),
            const Text('مقاس الورق (Paper Size)', style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButton<String>(
              items: const [
                DropdownMenuItem(value: '58mm', child: Text('58 مليمتراً (58mm)')),
                DropdownMenuItem(value: '80mm', child: Text('80 مليمتراً (80mm)')),
              ],
              onChanged: _updatePaperSize,
              value: _paperSize,
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _connected ? _disconnect : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _connected ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_connected ? 'قطع الاتصال' : 'اتصال', style: const TextStyle(fontFamily: 'Tajawal')),
                ),
                ElevatedButton(
                  onPressed: _initBluetooth,
                  child: const Text('تحديث الأجهزة', style: TextStyle(fontFamily: 'Tajawal')),
                ),
              ],
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: _connected ? Colors.green : Colors.black87),
              ),
            ),
            SizedBox(height: 16),
            if (_connected)
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    List<int> bytes = [];
                    // Using basic test string for PrintBluetoothThermal requires generating bytes
                    bytes.addAll([0x1B, 0x40]); // Init
                    bytes.addAll(utf8.encode("Test Print Successful\n\n\n"));
                    await PrintBluetoothThermal.writeBytes(bytes);
                  } catch (e) {
                    setState(() => _message = "خطأ في طباعة الاختبار: $e");
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('طباعة اختبار', style: TextStyle(fontFamily: 'Tajawal')),
              ),
          ],
        ),
      ),
    );
  }
}
