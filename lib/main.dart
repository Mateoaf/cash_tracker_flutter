import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_page.dart';
void main() {
  runApp(const CashTrackerApp());
}

class CashTrackerApp extends StatelessWidget {
  const CashTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      
      title: 'Cash Calculator',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E1A2A),
        primaryColor: Colors.tealAccent,
      ),
      home: const CashTrackerHomePage(),
    );
  }
}

class CashTrackerHomePage extends StatefulWidget {
  const CashTrackerHomePage({super.key});

  @override
  State<CashTrackerHomePage> createState() => _CashTrackerHomePageState();
}

class _CashTrackerHomePageState extends State<CashTrackerHomePage> {
  final List<int> denominations = [500, 200, 100, 50, 20, 10, 5];
  late Map<int, int> counts;

  @override
  void initState() {
    super.initState();
    counts = {for (var d in denominations) d: 0};
    _loadData();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      counts.map((key, value) => MapEntry(key.toString(), value)),
    );
    await prefs.setString('counts', jsonString);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('counts');
    if (jsonString != null) {
      final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
      setState(() {
        counts = decodedMap.map((key, value) => MapEntry(int.parse(key), value));
      });
    }
  }

  int get totalBills => counts.values.fold(0, (a, b) => a + b);
  double get totalAmount =>
      counts.entries.fold(0.0, (sum, e) => sum + e.key * e.value);

  void clearAll() {
    setState(() {
      counts.updateAll((key, value) => 0);
    });
    _saveData();
  }

  void _openScanner() async {
    // Pausa la cámara si ya está abierta (buena práctica)

    // Navega a la página de escaneo y ESPERA a que vuelva con un resultado
    final int? detectedDenomination = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );

    // Si el usuario escaneó algo (no solo pulsó "atrás")
    if (detectedDenomination != null) {
      // Comprueba si la denominación es válida
      if (denominations.contains(detectedDenomination)) {
        setState(() {
          // Incrementa el contador para ese billete
          counts[detectedDenomination] = counts[detectedDenomination]! + 1;
        });
        _saveData(); // Guarda los cambios
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Calculadora de Billetes",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent),
            ),
            const SizedBox(height: 6),
            const Text(
              "Registra tus billetes en euros y calcula el total.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: denominations.length,
                itemBuilder: (context, index) {
                  final value = denominations[index];
                  final count = counts[value]!;
                  final subtotal = value * count;

                  return Card(
                    color: const Color(0xFF152238),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "€ $value",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    if (counts[value]! > 0) {
                                      counts[value] = count - 1;
                                    }
                                  });
                                  _saveData();
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                "$count",
                                style: const TextStyle(fontSize: 18),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    counts[value] = count + 1;
                                  });
                                  _saveData();
                                },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          Text(
                            "${subtotal.toStringAsFixed(2)} €",
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2E44),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "Total Billetes: $totalBills",
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Total General",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${totalAmount.toStringAsFixed(2)} €",
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: clearAll,
              child: const Text(
                "Limpiar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
      onPressed: _openScanner, // ¡Añade esto!
      backgroundColor: Colors.tealAccent,
      child: const Icon(Icons.camera_alt, color: Colors.black),
    ),
    );
  }
}


