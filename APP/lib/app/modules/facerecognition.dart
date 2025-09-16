import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../routes/app_routes.dart';



class ReportDetailsPage extends StatefulWidget {
  final int reportId;
  const ReportDetailsPage({Key? key, required this.reportId}) : super(key: key);

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage> {
  double progress = 0.0;
  String statusText = "Waiting...";
  bool checking = false;
  String resultText = "";
  String stepText = "";

  Interpreter? interpreter;
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: false,
      enableContours: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    loadFaceModel().catchError((e, st) {
      debugPrint('Error loading model in ReportDetailsPage: $e\n$st');
    });
    _runCheck();
  }

  @override
  void dispose() {
    interpreter?.close();
    faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Searching",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Card-like container
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular progress style
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0
                                  ? Colors.green
                                  : const Color(0xFF4A90E2), // nice blue
                            ),
                          ),
                          Center(
                            child: Text(
                              "${(progress * 100).toInt()}%",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Status text
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _runCheck() async {
    setState(() {
      progress = 0.1;
      statusText = "Loading model…";
    });

    try {
      await loadFaceModel();

      setState(() {
        progress = 0.3;
        statusText = "Processing local images…";
      });

      final box = Hive.box('reports');
      final report = box.get(widget.reportId);
      if (report == null) {
        setState(() {
          progress = 1.0;
          statusText = "❌ Report not found";
        });
        return;
      }
      final List<Map<String, dynamic>> images =
      (report["images"] as List).cast<Map<String, dynamic>>();

      setState(() {
        progress = 0.5;
        statusText = "Retrieving from Supabase…";
      });

      final match = await checkAgainstSupabase(images,
          onStep: (msg, prog) {
            setState(() {
              statusText = msg;
              progress = prog;
            });
          });

      setState(() {
        progress = 1.0;
        statusText =
        match != null ? "✅ Match found" : "❌ No match in Supabase";
      });

      await Future.delayed(const Duration(seconds: 2));

      Get.toNamed(AppRoutes.MATCHES);
    } catch (e) {
      setState(() {
        progress = 1.0;
        statusText = "Error: $e";
      });
    }
  }

  Future<void> loadFaceModel() async {
    try {
      if (interpreter != null) {
        debugPrint("Model already loaded");
        return;
      }

      const assetPath = 'assets/facenet.tflite';
      final byteData = await rootBundle.load(assetPath);

      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDir.path}/facenet.tflite');
      await modelFile.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );

      interpreter = await Interpreter.fromFile(modelFile);
      debugPrint("Interpreter loaded from ${modelFile.path}");
    } catch (e, st) {
      debugPrint("Error loading face model: $e");
      debugPrint("Stack: $st");
      rethrow;
    }
  }

  List<double> normalize(List<double> embedding) {
    final norm = sqrt(embedding.fold<double>(0, (p, e) => p + e * e));
    if (norm == 0) return embedding;
    return embedding.map((e) => e / norm).toList();
  }

  double cosineSimilarity(List<double> e1, List<double> e2) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < e1.length; i++) {
      dot += e1[i] * e2[i];
      normA += e1[i] * e1[i];
      normB += e2[i] * e2[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  Future<Map<String, dynamic>?> checkAgainstSupabase(
      List<Map<String, dynamic>> images, {
        void Function(String msg, double prog)? onStep,
      }) async {
    final supabase = Supabase.instance.client;
    final storage = supabase.storage.from('person');

    final files = await storage.list();
    if (files.isEmpty) {
      onStep?.call("No files in Supabase", 0.6);
      return null;
    }

    if (interpreter == null) {
      await loadFaceModel();
    }

    int checked = 0;
    for (final imgData in images) {
      if (imgData["embedding"] == null) continue;
      final reportEmbedding = normalize(List<double>.from(imgData["embedding"]));

      for (final file in files) {
        checked++;
        onStep?.call("Checking ${file.name}…", 0.6 + checked / files.length * 0.3);

        final downloaded = await storage.download(file.name);
        Uint8List bytes = downloaded is Uint8List
            ? downloaded
            : Uint8List.fromList(downloaded as List<int>);

        final cropped = await detectAndCropFaceFromBytes(bytes);
        if (cropped == null) continue;

        final dbEmbedding = await getFaceEmbedding(cropped);
        final similarity = cosineSimilarity(reportEmbedding, dbEmbedding);

        if (similarity > 0.80) {
          return {
            "fileName": file.name,
            "bytes": bytes,
            "similarity": similarity,
          };
        }
      }
    }
    return null;
  }

  Future<img.Image?> detectAndCropFaceFromBytes(Uint8List imageBytes) async {
    debugPrint('detectAndCropFaceFromBytes: decoding image');
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      debugPrint('Failed to decode image bytes');
      return null;
    }

    final tmpPath = await writeBytesToTempFile(imageBytes);
    final inputImage = InputImage.fromFilePath(tmpPath);
    final faces = await faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      debugPrint('No faces detected by ML Kit');
      return null;
    }

    final faceRect = faces.first.boundingBox;
    final cropRect = Rect.fromLTWH(
      max(0, faceRect.left),
      max(0, faceRect.top),
      min(faceRect.width, originalImage.width - faceRect.left),
      min(faceRect.height, originalImage.height - faceRect.top),
    );

    final cropped = img.copyCrop(
      originalImage,
      x: cropRect.left.toInt(),
      y: cropRect.top.toInt(),
      width: cropRect.width.toInt(),
      height: cropRect.height.toInt(),
    );

    return cropped;
  }

  Future<String> writeBytesToTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp_report_image.jpg');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('Wrote temp file ${file.path}');
    return file.path;
  }

  Future<List<double>> getFaceEmbedding(img.Image faceImage) async {
    if (interpreter == null) {
      throw Exception('Model not loaded');
    }

    const inputSize = 112;
    final buffer = preprocess(faceImage, inputSize);

    final input = List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (y) => List.generate(
          inputSize,
              (x) => [
            buffer[(y * inputSize + x) * 3 + 0],
            buffer[(y * inputSize + x) * 3 + 1],
            buffer[(y * inputSize + x) * 3 + 2],
          ],
        ),
      ),
    );

    final output = List.generate(1, (_) => List<double>.filled(128, 0.0));

    interpreter!.run(input, output);
    final embedding = List<double>.from(output[0]);
    return normalize(embedding);
  }

  Float32List preprocess(img.Image image, int inputSize) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final buffer = Float32List(inputSize * inputSize * 3);

    int i = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final p = resized.getPixel(x, y);
        buffer[i++] = (p.r - 127.5) / 128.0;
        buffer[i++] = (p.g - 127.5) / 128.0;
        buffer[i++] = (p.b - 127.5) / 128.0;
      }
    }
    return buffer;
  }
}

