import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Irrigation',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _motorStatus = false;
  double _temperature = 0.0;
  int _humidity = 0;
  int _soilMoisture = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    // Listen for motor status changes
    _database.child('motorStatus').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _motorStatus = event.snapshot.value as bool;
        });
      }
    });

    // Listen for sensor data changes
    _database.child('sensors').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _temperature = (data['temperature'] as num).toDouble();
          _humidity = (data['humidity'] as num).toInt();
          _soilMoisture = (data['soilMoisture'] as num).toInt();
          _isLoading = false;
        });
      }
    });
  }

  void _toggleMotor() async {
    try {
      await _database.update({'motorStatus': !_motorStatus});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling motor: $e')),
      );
    }
  }

  String _getSoilMoistureStatus() {
    // Soil moisture values are typically inverted in sensors
    // Lower values mean more moisture
    if (_soilMoisture < 400) return 'Wet';
    if (_soilMoisture < 700) return 'Moist';
    return 'Dry';
  }

  Color _getSoilMoistureColor() {
    if (_soilMoisture < 400) return Colors.blue;
    if (_soilMoisture < 700) return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Irrigation Dashboard'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isLoading = true;
          });
          await Future.delayed(const Duration(seconds: 1));
          setState(() {
            _isLoading = false;
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMotorControl(),
              const SizedBox(height: 24),
              _buildSensorDataCards(),
              const SizedBox(height: 24),
              _buildSoilMoistureGauge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMotorControl() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Irrigation Pump',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Status: ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _motorStatus ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _motorStatus ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleMotor,
              icon: Icon(_motorStatus ? Icons.power_settings_new : Icons.power_off),
              label: Text(_motorStatus ? 'Turn OFF' : 'Turn ON'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _motorStatus ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorDataCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sensor Readings',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _sensorCard(
                'Temperature',
                '$_temperature°C',
                Icons.thermostat,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _sensorCard(
                'Humidity',
                '$_humidity%',
                Icons.water_drop,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sensorCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilMoistureGauge() {
    // Calculate percentage for visualization
    // Assuming 0-1024 range where 0 is wet and 1024 is dry
    final double percentage = (1024 - _soilMoisture) / 1024;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Soil Moisture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _getSoilMoistureStatus(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getSoilMoistureColor(),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 20,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getSoilMoistureColor()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Raw Value: $_soilMoisture',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dry', style: TextStyle(color: Colors.orange)),
                Text('Moist', style: TextStyle(color: Colors.green)),
                Text('Wet', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

