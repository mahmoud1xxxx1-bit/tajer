import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/services/printer_service.dart';

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

    final savedDevice = await PrinterService.getSavedDevice();
    if (savedDevice != null) {
      setState(() {
        _device = _devices.firstWhere(
          (d) => d.macAdress == savedDevice.macAdress,
          orElse: () => _devices.first,
        );
      });
    }
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
              hint: Text('اختر الطابعة', style: TextStyle(fontFamily: 'Tajawal')),
              isExpanded: true,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _connected ? _disconnect : _connect,
                  child: Text(_connected ? 'قطع الاتصال' : 'اتصال', style: TextStyle(fontFamily: 'Tajawal')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _connected ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: _initBluetooth,
                  child: Text('تحديث الأجهزة', style: TextStyle(fontFamily: 'Tajawal')),
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
                icon: Icon(Icons.print),
                label: Text('طباعة اختبار', style: TextStyle(fontFamily: 'Tajawal')),
              ),
          ],
        ),
      ),
    );
  }
}
