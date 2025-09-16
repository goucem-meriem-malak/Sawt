import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/theme/app_theme.dart';
import '../shared/widgets/custom_text_field.dart';
import '../shared/widgets/photo_upload_widget.dart';
import 'package:sawt/app/data/services/local_sync_service.dart';
import 'package:sawt/app/data/services/match_service.dart';

class ReportFoundPage extends StatefulWidget {
  const ReportFoundPage({super.key});

  @override
  State<ReportFoundPage> createState() => _ReportFoundPageState();
}

class _ReportFoundPageState extends State<ReportFoundPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();
  final finderNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final hospitalController = TextEditingController();

  final List<XFile> selectedImages = [];
  String selectedDate = '';
  String selectedCondition = 'alive';

  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();


  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: false,
      enableContours: false,
    ),
  );
  Interpreter? interpreter;

  @override
  void initState() {
    super.initState();
    _loadFaceModel();
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    finderNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    hospitalController.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> _loadFaceModel() async {
    try {
      if (interpreter != null) return;
      final byteData = await rootBundle.load('assets/facenet.tflite');
      final tempDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${tempDir.path}/facenet.tflite');
      await modelFile.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
      interpreter = Interpreter.fromFile(modelFile);
    } catch (_) {}
  }

  Future<void> addImage() async {
    final source = await showDialog<ImageSource>(
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
    if (source == null) return;
    final XFile? file = await _picker.pickImage(source: source);
    if (file != null) setState(() => selectedImages.add(file));
  }

  void removeImage(int index) => setState(() => selectedImages.removeAt(index));

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

  Future<String> _writeBytesToTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/temp_found.jpg');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<img.Image?> _detectFaceFromBytes(Uint8List imageBytes) async {
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return null;

    final inputImage = InputImage.fromFilePath(await _writeBytesToTemp(imageBytes));
    final faces = await faceDetector.processImage(inputImage);
    if (faces.isEmpty) return null;

    final face = faces.first.boundingBox;
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
    return cropped;
  }

  Float32List _preprocess(img.Image image, int inputSize) {
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

  List<double> _normalize(List<double> embedding) {
    final norm = sqrt(embedding.fold<double>(0, (p, e) => p + e * e));
    if (norm == 0) return embedding;
    return embedding.map((e) => e / norm).toList();
  }

  Future<List<double>> _getFaceEmbedding(img.Image faceImage) async {
    if (interpreter == null) throw Exception('Model not loaded');
    const inputSize = 112;
    final buffer = _preprocess(faceImage, inputSize);

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
    return _normalize(List<double>.from(output[0]));
  }

  Future<String> _uploadAndGetUrl({
    required SupabaseClient sp,
    required String bucket,
    required String userId,
    required XFile file,
    required int index,
  }) async {
    final ext = file.name.split('.').last.toLowerCase();
    final path = 'found/$userId/${DateTime.now().millisecondsSinceEpoch}_$index.$ext';

    await sp.storage.from(bucket).upload(
      path,
      File(file.path),
      fileOptions: const FileOptions(upsert: true),
    );

    return sp.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate() ||
        selectedImages.isEmpty ||
        selectedDate.isEmpty) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please sign in first")),
          );
        }
        return;
      }

      await _loadFaceModel();

      if (!Hive.isBoxOpen('reports')) await Hive.openBox('reports');
      final reportsBox = Hive.box('reports');

      if (!Hive.isBoxOpen('found_local')) await Hive.openBox('found_local');
      final foundBox = Hive.box('found_local');

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

        final cropped = await _detectFaceFromBytes(bytes);
        if (cropped != null) {
          final emb = await _getFaceEmbedding(cropped);
          myEmbeddings.add(emb);
          imageData.add({
            "path": file.path,
            "url": url,
            "embedding": emb.map((e) => e.toDouble()).toList(),
          });
          faces.add({'url': url, 'embedding': emb});
        } else {
          imageData.add({"path": file.path, "url": url, "embedding": null});
          faces.add({'url': url, 'embedding': null});
        }
      }

      DateTime? foundAt;
      try {
        foundAt = DateFormat('MMM dd, yyyy').parse(selectedDate);
      } catch (_) {}

      final String uid = authuser.id;

      final allowed = {'alive', 'injured', 'deceased'};
      final cond = allowed.contains(selectedCondition) ? selectedCondition : null;

      final payload = {
        'user_id'       : uid,
        'name'          : nameController.text.trim().isEmpty
            ? null
            : nameController.text.trim(),
        'estimated_age' : int.tryParse(ageController.text.trim()),
        'location'      : locationController.text.trim(),
        'found_date'    : foundAt?.toIso8601String(),
        'photo_urls'    : photoUrls,
        'condition'     : cond,
        'description'   : descriptionController.text.trim(),
        'finder_name'   : finderNameController.text.trim(),
        'finder_phone'  : phoneController.text.trim(),
        'finder_email'  : emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        'hospital_info' : hospitalController.text.trim(),
        'status'        : 'found',
        'face_embeddings': {'images': faces},
      };

      final inserted = await sp
          .from('found_persons')
          .insert(payload)
          .select('id')
          .single();
      final remoteId = inserted['id'] as String;

      final displayReport = {
        "reported_full_name": nameController.text,
        "reported_age": ageController.text,
        "reported_location": locationController.text,
        "reported_date": selectedDate,
        "reported_description": descriptionController.text,
        "reporter_Name": finderNameController.text,
        "reporter_phone": phoneController.text,
        "reporter_email": emailController.text,
        "images": imageData,
        "createdAt": DateTime.now().toIso8601String(),
        "sync": {"status": "synced", "remote_id": remoteId},
      };
      await reportsBox.add(displayReport);

      final foundItem = {
        'user_id'       : uid,
        "name"          : nameController.text.trim().isEmpty
            ? null
            : nameController.text.trim(),
        "estimated_age" : int.tryParse(ageController.text.trim()),
        "location"      : locationController.text.trim(),
        "found_date"    : foundAt?.toIso8601String(),
        "condition"     : cond,
        "description"   : descriptionController.text.trim(),
        "finder_name"   : finderNameController.text.trim(),
        "finder_phone"  : phoneController.text.trim(),
        "finder_email"  : emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        "hospital_info" : hospitalController.text.trim(),
        "photos"        : imageData,
        "created_at"    : DateTime.now().toIso8601String(),
        "sync"          : {"status": "synced", "remote_id": remoteId},
      };
      final fkey = await foundBox.add(foundItem);

      try {
        await LocalSyncService.syncOne(boxName: 'found_local', key: fkey);
      } catch (_) {}

      final foundId = inserted['id'] as String;

      await MatchService.checkAndRoute(
        isMissing: false,
        currentId: foundId,
        myEmbeddings: myEmbeddings,
        context: context,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Found report submitted successfully")),
      );

      setState(() {
        selectedImages.clear();
        selectedDate = '';
        selectedCondition = 'alive';
        nameController.clear();
        ageController.clear();
        locationController.clear();
        descriptionController.clear();
        finderNameController.clear();
        phoneController.clear();
        emailController.clear();
        hospitalController.clear();
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Supabase error: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error saving report")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Found Person'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please provide clear photos and accurate information to help us identify the found person.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                "Photos *",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              PhotoUploadWidget(
                images: selectedImages,
                onImageAdded: addImage,
                onImageRemoved: removeImage,
                maxImages: 5,
              ),
              const SizedBox(height: 32),

              Text(
                "Person Information",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Full Name (optional)',
                hint: 'Enter person\'s name if known',
                controller: nameController,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Estimated Age *',
                hint: 'Enter estimated age',
                controller: ageController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final age = int.tryParse(v);
                  if (age == null || age < 0 || age > 120) return 'Invalid age';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Found Location *',
                hint: 'City, area, or address',
                controller: locationController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedDate.isEmpty ? 'Found Date *' : selectedDate,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: selectedDate.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text("Condition", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCondition,
                items: const [
                  DropdownMenuItem(value: 'alive', child: Text('Alive')),
                  DropdownMenuItem(value: 'injured', child: Text('Injured')),
                  DropdownMenuItem(value: 'deceased', child: Text('Deceased')),
                ],
                onChanged: (v) => setState(() => selectedCondition = v ?? 'alive'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Description',
                hint: 'Physical features, clothing...',
                controller: descriptionController,
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              Text(
                "Your Contact Information",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Your Name *',
                hint: 'Enter your name',
                controller: finderNameController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Email (optional)',
                hint: 'Enter your email',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Hospital/Notes',
                hint: 'Hospital info or additional notes',
                controller: hospitalController,
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : submitReport,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
