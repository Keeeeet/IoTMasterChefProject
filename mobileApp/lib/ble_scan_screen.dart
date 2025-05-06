import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  late Stream<DiscoveredDevice> _scanStream;
  final List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions().then((_) {
      _startScan();
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void _startScan() {
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    _scanStream = _ble.scanForDevices(withServices: [], scanMode: ScanMode.lowLatency);

    _scanStream.listen((device) {
      final known = _devices.any((d) => d.id == device.id);
      if (!known && device.name.isNotEmpty) {
        setState(() => _devices.add(device));
      }
    }, onError: (e) {
      print('Scan failed: $e');
      setState(() => _isScanning = false);
    }, onDone: () {
      setState(() => _isScanning = false);
    });

    Future.delayed(const Duration(seconds: 5), () {
      _ble.deinitialize(); // Останавливает скан
      setState(() => _isScanning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyhledávání zařízení'),
      ),
      body: Column(
        children: [
          if (_isScanning)
            const LinearProgressIndicator()
          else
            ElevatedButton(
              onPressed: _startScan,
              child: const Text('Znovu skenovat'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text(device.id),
                  onTap: () {
                    Navigator.pop(context, device);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
