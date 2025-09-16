import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:sawt/app/data/services/local_sync_service.dart';
import 'package:sawt/app/data/services/match_service.dart';
import '../core/theme/app_theme.dart';
import '../shared/widgets/custom_text_field.dart';
import '../shared/widgets/photo_upload_widget.dart';


class ReportMissingPage extends StatefulWidget {
  const ReportMissingPage({super.key});

  @override
  _ReportMissingPageState createState() => _ReportMissingPageState();
}

class _ReportMissingPageState extends State<ReportMissingPage> {
  final picker = ImagePicker();
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: false,
      enableContours: false,
    ),
  );
  Interpreter? interpreter;

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();
  final reporterNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  final List<XFile> selectedImages = [];
  String selectedDate = '';
  bool isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print("✅ ReportMissingPage opened!");
    _loadModel();
  }

  Future<void> _loadModel() async {
    debugPrint('✅ _loadModel: Loading model…');
    try {
      await loadFaceModel();
      debugPrint('✅ _loadModel: Model loaded successfully');
    } catch (e) {
      debugPrint('❌ _loadModel failed: $e');
    }
  }

  Future<void> loadFaceModel() async {
    try {
      if (interpreter != null) {
        debugPrint("✅ Face model already loaded");
        return;
      }

      final byteData = await rootBundle.load('assets/facenet.tflite');
      final tempDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${tempDir.path}/facenet.tflite');
      await modelFile.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );

      interpreter = Interpreter.fromFile(modelFile);
      debugPrint("✅ Face model loaded from ${modelFile.path}");
    } catch (e, st) {
      debugPrint("❌ Error loading face model: $e");
      debugPrint("StackTrace: $st");
      rethrow;
    }
  }

  Future<void> addImage() async {
    final result = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final XFile? image = await _picker.pickImage(source: result);
      if (image != null) {
        setState(() => selectedImages.add(image));
      }
    }
  }

  void removeImage(int index) {
    setState(() => selectedImages.removeAt(index));
  }

  Future<void> selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<img.Image?> detectFaceFromBytes(Uint8List imageBytes) async {
    debugPrint('✅ detectFaceFromBytes: Decoding image');
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      debugPrint('❌ detectFaceFromBytes: Failed to decode image');
      return null;
    }

    final inputImage = InputImage.fromFilePath(await writeBytesToTempFile(imageBytes));
    final faces = await faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      debugPrint('❌ detectFaceFromBytes: No faces detected');
      return null;
    }

    final face = faces.first.boundingBox;
    debugPrint('✅ detectFaceFromBytes: Face detected at $face');

    final cropRect = Rect.fromLTWH(
      max(0, face.left),
      max(0, face.top),
      min(face.width, originalImage.width - face.left),
      min(face.height, originalImage.height - face.top),
    );

    final cropped = img.copyCrop(
      originalImage,
      x: cropRect.left.toInt(),
      y: cropRect.top.toInt(),
      width: cropRect.width.toInt(),
      height: cropRect.height.toInt(),
    );

    debugPrint('✅ detectFaceFromBytes: Face cropped');
    return cropped;
  }

  Future<String> writeBytesToTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp.jpg');
    await file.writeAsBytes(bytes);
    debugPrint('✅ writeBytesToTempFile: Written bytes to ${file.path}');
    return file.path;
  }

  Future<List<double>> getFaceEmbedding(img.Image faceImage) async {
    if (interpreter == null) {
      throw Exception('❌ Model not loaded! Call loadFaceModel() first.');
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

    debugPrint('✅ getFaceEmbedding: Running interpreter…');
    interpreter!.run(input, output);
    debugPrint('✅ getFaceEmbedding: Interpreter finished.');

    final embedding = List<double>.from(output[0]);
    return normalize(embedding);
  }

  List<double> normalize(List<double> embedding) {
    final norm = sqrt(embedding.fold<double>(0, (p, e) => p + e * e));
    if (norm == 0) return embedding;
    return embedding.map((e) => e / norm).toList();
  }

  Float32List preprocess(img.Image image, int inputSize) {
    debugPrint('✅ preprocess: Resizing image to $inputSize x $inputSize');
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
    debugPrint('✅ preprocess: Finished preprocessing');
    return buffer;
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate() || selectedImages.isEmpty || selectedDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final sp = Supabase.instance.client;
      final authuser = sp.auth.currentUser;
      if (authuser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please sign in first")),
        );
        return;
      }

      await loadFaceModel();

      if (!Hive.isBoxOpen('reports')) await Hive.openBox('reports');
      final reportsBox = Hive.box('reports');

      if (!Hive.isBoxOpen('missing_local')) await Hive.openBox('missing_local');
      final missingBox = Hive.box('missing_local');

      const bucketName = 'person';
      final List<String> photoUrls = [];
      final List<Map<String, dynamic>> imageData = [];
      final List<Map<String, dynamic>> faces = [];
      final myEmbeddings = <List<double>>[];

      for (int i = 0; i < selectedImages.length; i++) {
        final file = selectedImages[i];
        final bytes = await file.readAsBytes();

        final url = await _uploadAndGetUrl(
          sp: sp,
          bucket: bucketName,
          userId: authuser.id,
          file: file,
          index: i,
        );
        photoUrls.add(url);

        final cropped = await detectFaceFromBytes(bytes);
        if (cropped != null) {
          final emb = await getFaceEmbedding(cropped);
          myEmbeddings.add(emb);
          imageData.add({"path": file.path, "url": url, "embedding": emb.map((e) => e.toDouble()).toList()});
          faces.add({'url': url, 'embedding': emb});
        } else {
          imageData.add({"path": file.path, "url": url, "embedding": null});
          faces.add({'url': url, 'embedding': null});
        }
      }

      DateTime? lastSeen;
      try {
        lastSeen = DateFormat('MMM dd, yyyy').parse(selectedDate);
      } catch (_) {}

      final String uid = authuser.id;
      final payload = {
        'user_id': uid,
        'name': nameController.text.trim(),
        'age': int.tryParse(ageController.text.trim()),
        'last_seen_location': locationController.text.trim(),
        'last_seen_date': lastSeen?.toIso8601String(),
        'photo_urls': photoUrls,
        'description': descriptionController.text.trim(),
        'reporter_name': reporterNameController.text.trim(),
        'reporter_phone': phoneController.text.trim(),
        'reporter_email': emailController.text.trim(),
        'status': 'missing',
        'face_embeddings': {'images': faces},
      };

      final inserted = await sp
          .from('missing_persons')
          .insert(payload)
          .select('id')
          .single();
      final remoteId = inserted['id'] as String;

      final displayReport = {
        "name": nameController.text,
        "reported_age": ageController.text,
        "reported_location": locationController.text,
        "reported_date": selectedDate,
        "reported_description": descriptionController.text,
        "reporter_Name": reporterNameController.text,
        "reporter_phone": phoneController.text,
        "reporter_email": emailController.text,
        "images": imageData,
        "createdAt": DateTime.now().toIso8601String(),
        "sync": {"status": "synced", "remote_id": remoteId},
      };
      await reportsBox.add(displayReport);

      final missingItem = {
        'user_id': uid,
        "name": nameController.text.trim(),
        "age": int.tryParse(ageController.text.trim()),
        "last_seen_location": locationController.text.trim(),
        "last_seen_date": lastSeen?.toIso8601String(),
        "description": descriptionController.text.trim(),
        "reporter_name": reporterNameController.text.trim(),
        "reporter_phone": phoneController.text.trim(),
        "reporter_email": emailController.text.trim(),
        "photos": imageData,
        "created_at": DateTime.now().toIso8601String(),
        "sync": {"status": "synced", "remote_id": remoteId},
      };
      final mkey = await missingBox.add(missingItem);

      try {
        await LocalSyncService.syncOne(boxName: 'missing_local', key: mkey);
      } catch (e, st) {
        debugPrint('❌ Sync background failed: $e\n$st');
      }

      final missingId = inserted['id'] as String;

      await MatchService.checkAndRoute(
        isMissing: true,
        currentId: missingId,
        myEmbeddings: myEmbeddings,
        context: context,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing report submitted successfully")),
      );

      setState(() {
        selectedImages.clear();
        selectedDate = '';
        nameController.clear();
        ageController.clear();
        locationController.clear();
        descriptionController.clear();
        reporterNameController.clear();
        phoneController.clear();
        emailController.clear();
      });

    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase insert error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Supabase error: ${e.message}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error saving report: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error saving report")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<String> _uploadAndGetUrl({
    required SupabaseClient sp,
    required String bucket,
    required String userId,
    required XFile file,
    required int index,
  }) async {
    final ext = file.name.split('.').last.toLowerCase();
    final path = 'missing/$userId/${DateTime.now().millisecondsSinceEpoch}_$index.$ext';

    await sp.storage.from(bucket).upload(
      path,
      File(file.path),
      fileOptions: const FileOptions(upsert: true),
    );

    return sp.storage.from(bucket).getPublicUrl(path);
  }


  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    reporterNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Missing Person'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withAlpha(77),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppTheme.primaryColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please provide clear photos and accurate information to help us find your missing person.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // Photos
              Text("Photos *", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: 16),
              PhotoUploadWidget(
                images: selectedImages,
                onImageAdded: addImage,
                onImageRemoved: removeImage,
                maxImages: 5,
              ),
              SizedBox(height: 32),

              // Personal Info
              Text("Personal Information", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Full Name *',
                hint: 'Enter the missing person\'s full name',
                controller: nameController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Age *',
                hint: 'Enter age',
                controller: ageController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final age = int.tryParse(v);
                  if (age == null || age < 0 || age > 120) return 'Invalid age';
                  return null;
                },
              ),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Last Seen Location *',
                hint: 'City, area, or address',
                controller: locationController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),

              InkWell(
                onTap: selectDate,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedDate.isEmpty ? 'Last Seen Date *' : selectedDate,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: selectedDate.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Description',
                hint: 'Physical features, clothing...',
                controller: descriptionController,
                maxLines: 4,
              ),
              SizedBox(height: 32),

              // Contact
              Text("Your Contact Information", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Your Name *',
                hint: 'Enter your name',
                controller: reporterNameController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Phone Number *',
                hint: 'Enter your phone number',
                controller: phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 10) return 'Invalid phone number';
                  return null;
                },
              ),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Email Address *',
                hint: 'Enter your email',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!regex.hasMatch(v)) return 'Invalid email';
                  return null;
                },
              ),
              SizedBox(height: 40),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : submitReport,
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


