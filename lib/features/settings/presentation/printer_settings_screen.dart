import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../core/services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  String _message = 'لم يتم الاتصال بأي طابعة';

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    bool? isConnected = await bluetooth.isConnected;
    List<BluetoothDevice> devices = [];
    try {
      devices = await bluetooth.getBondedDevices();
    } catch (e) {
      _message = "خطأ في البحث عن الأجهزة: $e";
    }

    bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BlueThermalPrinter.CONNECTED:
          setState(() {
            _connected = true;
            _message = "تم الاتصال";
          });
          break;
        case BlueThermalPrinter.DISCONNECTED:
          setState(() {
            _connected = false;
            _message = "تم قطع الاتصال";
          });
          break;
        default:
          break;
      }
    });

    if (!mounted) return;
    setState(() {
      _devices = devices;
      _connected = isConnected ?? false;
    });

    final savedDevice = await PrinterService.getSavedDevice();
    if (savedDevice != null) {
      setState(() {
        _device = _devices.firstWhere((d) => d.address == savedDevice.address, orElse: () => _devices.first);
      });
    }
  }

  Future<void> _connect() async {
    if (_device != null) {
      setState(() => _message = "جاري الاتصال...");
      bool connected = await PrinterService.connect(_device!);
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
            DropdownButton<BluetoothDevice>(
              items: _devices.map((device) => DropdownMenuItem(
                child: Text(device.name ?? 'Unknown Device'),
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
                    BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
                    bluetooth.printCustom("Test Print Successful", 1, 1);
                    bluetooth.printNewLine();
                    bluetooth.printNewLine();
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
