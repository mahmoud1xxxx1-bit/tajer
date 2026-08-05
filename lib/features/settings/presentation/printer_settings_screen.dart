import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/services/printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/glass_card.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _device;
  bool _connected = false;
  String? _message;
  String _paperSize = '58mm';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    setState(() => _isLoading = true);
    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    List<BluetoothInfo> devices = [];
    try {
      devices = await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      if (mounted) {
        _message = AppLocalizations.of(context)!.printerErrorConnecting;
      }
    }

    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceMac = prefs.getString('default_printer_mac');
    final savedPaperSize = prefs.getString('printer_paper_size') ?? '58mm';

    setState(() {
      _devices = devices;
      _connected = isConnected;
      _paperSize = savedPaperSize;
      
      if (savedDeviceMac != null && _devices.isNotEmpty) {
        try {
          _device = _devices.firstWhere((d) => d.macAdress == savedDeviceMac);
        } catch (_) {
          _device = _devices.first;
        }
      } else if (_devices.isNotEmpty) {
        _device = _devices.first;
      }
      
      _isLoading = false;
    });
  }

  Future<void> _updatePaperSize(String? size) async {
    if (size == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_paper_size', size);
    setState(() => _paperSize = size);
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context)!;
    if (_device != null) {
      setState(() => _message = l10n.printerConnecting);
      bool connected = await PrinterService.connect(_device!.macAdress);
      if (connected) {
        setState(() {
          _connected = true;
          _message = l10n.printerConnectedSuccess;
        });
      } else {
        setState(() => _message = l10n.printerConnectionFailed);
      }
    } else {
      setState(() => _message = l10n.printerSelectFirst);
    }
  }

  Future<void> _disconnect() async {
    await PrinterService.disconnect();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _connected = false;
      _message = l10n.printerDisconnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsThermalPrinter, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 12, bottom: 12),
                child: Text(
                  l10n.printerConnectionSettings,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bluetooth_connected_rounded, color: Colors.blueAccent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l10n.printerSelectDevice, style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BluetoothInfo>(
                            isExpanded: true,
                            items: _devices.map((device) => DropdownMenuItem(
                              value: device,
                              child: Text(device.name, style: const TextStyle(fontFamily: 'Tajawal')),
                            )).toList(),
                            onChanged: (value) => setState(() => _device = value),
                            value: _device,
                            hint: Text(l10n.printerSelectHint, style: const TextStyle(fontFamily: 'Tajawal')),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Colors.orangeAccent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l10n.printerPaperSize, style: const TextStyle(fontSize: 14, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: '58mm', child: Text(l10n.printerSize58, style: const TextStyle(fontFamily: 'Tajawal'))),
                              DropdownMenuItem(value: '80mm', child: Text(l10n.printerSize80, style: const TextStyle(fontFamily: 'Tajawal'))),
                            ],
                            onChanged: _updatePaperSize,
                            value: _paperSize,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _initBluetooth,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(l10n.printerRefresh, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _connected ? _disconnect : _connect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _connected ? Colors.redAccent : Colors.green.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_connected ? l10n.printerDisconnect : l10n.printerConnect, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _connected ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _connected ? Colors.green.withOpacity(0.3) : Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_connected ? Icons.check_circle_rounded : Icons.info_rounded, color: _connected ? Colors.green : Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message ?? l10n.printerNotConnected,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: _connected ? Colors.green.shade800 : Colors.amber.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
