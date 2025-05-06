// home_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';

import 'developer_info_screen.dart';
import 'product_selection_screen.dart';
import 'ble_scan_screen.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double currentTemp = 0.0;
  double targetTemp = 100.0;
  bool isConnected = false;
  bool hasNotified = false;

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  DiscoveredDevice? connectedDevice;
  QualifiedCharacteristic? tempChar;
  final List<FlSpot> _tempHistory = [];
  final Stopwatch _stopwatch = Stopwatch();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Uuid serviceUuid = Uuid.parse("181A");
  final Uuid charUuid = Uuid.parse("2A6E");

  int currentWindowStart = 0;

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zadejte cílovou teplotu'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Např. 74.25'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
          TextButton(
            onPressed: () {
              final input = controller.text.trim().replaceAll(',', '.');
              final value = double.tryParse(input);
              if (value == null || value < 0 || value > 1200) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Neplatná teplota! Rozsah: 0 až 1200 °C'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              setState(() {
                targetTemp = value;
                hasNotified = false;
              });
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductSelectionScreen()),
    );
    if (result != null && result is String) {
      final match = RegExp(r'(\d+)°C').firstMatch(result);
      if (match != null) {
        setState(() {
          targetTemp = double.parse(match.group(1)!);
          hasNotified = false;
        });
      }
    }
  }

  void _connectToDevice() async {
    final device = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BleScanScreen()),
    );

    if (device == null || device is! DiscoveredDevice) return;

    setState(() {
      isConnected = false;
      connectedDevice = device;
      currentTemp = 0;
      _tempHistory.clear();
      _stopwatch.reset();
      currentWindowStart = 0;
    });

    _ble.connectToDevice(id: device.id).listen(
          (update) {
        if (update.connectionState == DeviceConnectionState.connected) {
          setState(() => isConnected = true);
          _subscribeToTemperature(device);
          _stopwatch.start();
        } else if (update.connectionState == DeviceConnectionState.disconnected) {
          setState(() => isConnected = false);
          _stopwatch.stop();
        }
      },
      onError: (e) {
        print('Connection error: $e');
        setState(() => isConnected = false);
      },
    );
  }

  void _subscribeToTemperature(DiscoveredDevice device) {
    final char = QualifiedCharacteristic(
      deviceId: device.id,
      serviceId: serviceUuid,
      characteristicId: charUuid,
    );

    _ble.subscribeToCharacteristic(char).listen(
          (data) {
        if (data.length >= 2) {
          final raw = ByteData.sublistView(Uint8List.fromList(data)).getInt16(0, Endian.little);
          final temp = raw / 100.0;
          final time = _stopwatch.elapsed.inSeconds.toDouble() / 60.0;


          if (time > currentWindowStart + 5) {
            setState(() {
              currentWindowStart += 5;
              _tempHistory.clear();
            });
          }

          setState(() {
            currentTemp = temp;
            _tempHistory.add(FlSpot(time, temp));
            if (_tempHistory.length > 300) _tempHistory.removeAt(0);

            if (currentTemp >= targetTemp && !hasNotified) {
              hasNotified = true;
              _playNotification();
              _showSystemNotification();
            }
          });
        }
      },
      onError: (e) => print('Notification error: $e'),
    );
  }

  void _playNotification() async {
    await _audioPlayer.play(AssetSource('beep.mp3'));
  }

  void _showSystemNotification() {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'temp_channel',
      'Teplotní upozornění',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    notificationsPlugin.show(
      0,
      'Teplota dosažena!',
      'Dosažena cílová teplota: ${targetTemp.toStringAsFixed(1)}°C',
      details,
    );
  }

  Widget _buildGraph() {
    if (_tempHistory.length < 2) {
      return const Text('Zatím žádná data pro graf.');
    }

    final maxY = (_tempHistory.map((e) => e.y).reduce((a, b) => a > b ? a : b) / 100).ceil() * 100;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: currentWindowStart.toDouble(),
          maxX: (currentWindowStart + 5).toDouble(),
          minY: 0,
          maxY: maxY.toDouble(),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text("Čas (min)", style: TextStyle(fontSize: 10)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 32,
                getTitlesWidget: (value, _) =>
                    Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10)),
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _tempHistory,
              isCurved: true,
              color: Colors.deepOrange,
              barWidth: 2,
              dotData: FlDotData(show: false),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ble.deinitialize();
    _stopwatch.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('#IoTMasterChef'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bluetooth, color: isConnected ? Colors.green : Colors.red),
            onPressed: _connectToDevice,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperInfoScreen()));
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularPercentIndicator(
              radius: 100.0,
              lineWidth: 15.0,
              percent: (currentTemp / targetTemp).clamp(0.0, 1.0),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${currentTemp.toStringAsFixed(2)}°C', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${targetTemp.toStringAsFixed(2)}°C', style: const TextStyle(fontSize: 14, color: Colors.red)),
                ],
              ),
              progressColor: Colors.red,
              backgroundColor: Colors.grey.shade300,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: _showManualInputDialog,
                child: const Text('Zadat teplotu ručně'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: _selectProduct,
                child: const Text('Vybrat produkt'),
              ),
            ),
            const SizedBox(height: 25),
            if (!isConnected)
              const Text('Připojte zařízení pro zobrazení grafu.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildGraph(),
              ),
          ],
        ),
      ),
    );
  }
}
