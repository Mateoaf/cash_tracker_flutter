import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  Interpreter? _interpreter;
  List<String>? _labels;

  bool _isDetecting = false;
  String _statusText = "Apunta al billete y pulsa el botón";

  // --- CONFIGURACIÓN DEL MODELO ---
  // Estos valores coinciden con tus archivos
  final String _modelPath = 'assets/model.tflite';
  final String _labelsPath = 'assets/labels.txt';
  final int _inputSize = 224; // 224x224 es el estándar de Teachable Machine
  final double _confidenceThreshold =
      0.2; // 50% de confianza para aceptar la detección
  // ---------------------------------

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initTfLite();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();
    if (mounted) {
      setState(() {}); // Actualiza la UI para el FutureBuilder
    }
  }

  Future<void> _initTfLite() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n');
    } catch (e) {
      debugPrint("Error al cargar el modelo TFLite: $e");
      if (mounted) {
        setState(() {
          _statusText = "Error al cargar modelo";
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escanear Billete"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (_controller == null || !_controller!.value.isInitialized) {
              return const Center(
                  child: Text("Error al iniciar la cámara",
                      style: TextStyle(color: Colors.white)));
            }

            // --- UI Principal ---
            return Stack(
              fit: StackFit.expand,
              children: [
                // Visor de la cámara
                CameraPreview(_controller!),
                // Overlay semi-transparente
                _buildScanningOverlay(),
                // Botón de captura y texto de estado
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildControls(),
                ),
              ],
            );
          } else {
            // Mientras espera, muestra un spinner
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black.withOpacity(0.5),
      child: Column(
        children: [
          Text(
            _statusText,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _isDetecting ? null : _onScanButtonPressed,
            backgroundColor: _isDetecting ? Colors.grey : Colors.tealAccent,
            child: _isDetecting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.camera_alt, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    // Crea un "marco" visual para que el usuario sepa dónde apuntar
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: (MediaQuery.of(context).size.width * 0.9) *
            0.5, // Ratio aproximado de un billete
        decoration: BoxDecoration(
          border: Border.all(color: Colors.tealAccent, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

 // Reemplaza esta función entera
  Future<void> _onScanButtonPressed() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _interpreter == null ||
        _labels == null) {
      return;
    }
    if (_isDetecting) return;

    setState(() {
      _isDetecting = true;
      _statusText = "Escaneando...";
    });

    try {
      // 1. Tomar la foto
      final XFile picture = await _controller!.takePicture();
      final Uint8List bytes = await picture.readAsBytes();

      // 2. Procesar la imagen
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("No se pudo decodificar");

      // --- ¡INICIO DE LA MODIFICACIÓN! ---
      // La imagen de la cámara no es cuadrada (ej: 4000x3000).
      // El modelo espera una entrada cuadrada (ej: 224x224).
      // En lugar de "aplastar" la imagen, recortamos el cuadrado central.

      // 2a. Encontrar el tamaño del cuadrado más grande que podemos recortar
      int size = originalImage.width < originalImage.height
          ? originalImage.width
          : originalImage.height;

      // 2b. Encontrar las coordenadas (x,y) para empezar el recorte
      int x = (originalImage.width - size) ~/ 2;
      int y = (originalImage.height - size) ~/ 2;

      // 2c. Recortar la imagen
      img.Image croppedImage =
          img.copyCrop(originalImage, x: x, y: y, width: size, height: size);

      // 2d. Ahora, redimensiona la imagen YA RECORTADA al tamaño del modelo
      img.Image resizedImage = img.copyResize(
        croppedImage, // <-- ¡Usamos la imagen recortada!
        width: _inputSize,
        height: _inputSize,
      );
      // --- ¡FIN DE LA MODIFICACIÓN! ---

      // 3. Convierte la imagen a un Uint8List
      Uint8List inputTensor = _imageToByteList(resizedImage);

      // 4. Preparar tensores de entrada y salida
      var output = List.filled(1 * _labels!.length, 0)
          .reshape([1, _labels!.length]);

      // 5. Ejecutar el modelo
      _interpreter!.run(inputTensor.reshape([1, _inputSize, _inputSize, 3]), output);

      // 6. Procesar el resultado
      List<int> outputList = output[0].cast<int>();
      int maxScore = outputList.reduce(
          (curr, next) => curr > next ? curr : next);
      int maxIndex = outputList.indexOf(maxScore);
      double confidence = maxScore / 255.0;
      String detectedLabel = _labels![maxIndex];

      debugPrint("Detectado: $detectedLabel, Confianza: $confidence");

      // 7. Validar y devolver
      if (confidence >= _confidenceThreshold) {
        int? denomination = _parseLabel(detectedLabel);
        if (denomination != null) {
          // ¡Éxito!
          if (mounted) {
            Navigator.pop(context, denomination);
          }
          return;
        } else {
          // Detectó "Fondo" con alta confianza
          setState(() {
            _statusText =
                "No se detectó un billete. Intenta de nuevo.";
          });
        }
      } else {
        // No hay suficiente confianza, PERO mostramos qué vio
        setState(() {
          _statusText =
              "Detectado: $detectedLabel (${(confidence * 100).toStringAsFixed(0)}%)\nNo es suficiente. Intenta de nuevo.";
        });
      }
    } catch (e) {
      debugPrint("Error al escanear: $e");
      setState(() {
        _statusText = "Error. Intenta de nuevo.";
      });
    }

    // Si llegamos aquí, la detección falló o no fue segura
    setState(() {
      _isDetecting = false;
    });
  }

  /// Convierte una [img.Image] a [Uint8List] para el modelo TFLite (cuantizado)
  Uint8List _imageToByteList(img.Image image) {
    var bytes = Uint8List(_inputSize * _inputSize * 3);
    var buffer = bytes.buffer.asUint8List();
    int pixelIndex = 0;
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        var pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r.toInt();
        buffer[pixelIndex++] = pixel.g.toInt();
        buffer[pixelIndex++] = pixel.b.toInt();
      }
    }
    return bytes;
  }

  /// Convierte la etiqueta de tu 'labels.txt' (ej: "1 5 euros") a un entero (5)
  int? _parseLabel(String label) {
    // Tus etiquetas son:
    // "0 Fondo"
    // "1 5 euros"
    // "2 10 euros"
    // "3 20 euros"
    // "4 50 euros"

    // Si es "Fondo", no es un billete.
    if (label.toLowerCase().contains('fondo')) {
      return null;
    }

    // Divide la etiqueta por espacios: ["1", "5", "euros"]
    var parts = label.split(' ');
    
    // Comprueba si hay al menos 2 partes y la segunda es un número
    if (parts.length > 1) {
      int? denomination = int.tryParse(parts[1]);
      if (denomination != null) {
        // ¡Encontrado! Devuelve 5, 10, 20 o 50
        return denomination;
      }
    }
    
    // No se pudo parsear
    return null;
  }
}