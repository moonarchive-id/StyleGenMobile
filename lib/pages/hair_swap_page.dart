import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:photo_view/photo_view.dart';
import '../providers/network_discovery_provider.dart';
import '../providers/history_provider.dart';
import '../providers/image_state_provider.dart';

class HairSwapPage extends StatefulWidget {
  const HairSwapPage({super.key});

  @override
  State<HairSwapPage> createState() => _HairSwapPageState();
}

class _HairSwapPageState extends State<HairSwapPage> with AutomaticKeepAliveClientMixin {
  File? _faceImage;
  File? _shapeImage;
  File? _colorImage;

  Uint8List? _generatedSwapImageBytes;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final double _genderValue = 0.0;
  final double _ageValue = 0.0;

  double _progressValue = 0.0;
  Timer? _progressTimer;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;
  int _estimatedDurationInMs = 15000;

  final ScrollController _scrollController = ScrollController();
  String? _lastProcessInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Provider.of<ImageStateProvider>(context, listen: false).addListener(_onEditedFaceChanged);
    _loadLastUsedImages();
    _loadEstimatedDuration();
  }

  @override
  void dispose() {
    Provider.of<ImageStateProvider>(context, listen: false).removeListener(_onEditedFaceChanged);
    _progressTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadEstimatedDuration() async {
    final prefs = await SharedPreferences.getInstance();
    _estimatedDurationInMs = prefs.getInt('lastSwapDuration') ?? 15000;
  }

  Future<void> _saveLastDuration(int durationMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSwapDuration', durationMs);
    _estimatedDurationInMs = durationMs;
  }

  void _startProgressAnimation() {
    _progressTimer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();
    _progressValue = 0.0;
    _elapsedSeconds = 0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isLoading) {
        timer.cancel();
        return;
      }
      setState(() {
        double progress = _stopwatch.elapsedMilliseconds / _estimatedDurationInMs;
        _progressValue = progress.clamp(0.0, 0.95);
        _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      });
    });
  }

  void _stopProgressAnimation() {
    _stopwatch.stop();
    _progressTimer?.cancel();
    setState(() {
      _progressValue = 1.0;
    });
  }

  void _onEditedFaceChanged() {
    final imageBytes = Provider.of<ImageStateProvider>(context, listen: false).editedFaceImage;
    if (imageBytes != null) {
      _loadInitialFaceImage(imageBytes);
      Provider.of<ImageStateProvider>(context, listen: false).clearEditedFace();
    }
  }

  Future<void> _loadLastUsedImages() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShapePath = prefs.getString('lastShapeImagePath');
    final lastColorPath = prefs.getString('lastColorImagePath');

    if (lastShapePath != null && File(lastShapePath).existsSync()) {
      setState(() => _shapeImage = File(lastShapePath));
    }
    if (lastColorPath != null && File(lastColorPath).existsSync()) {
      setState(() => _colorImage = File(lastColorPath));
    }
  }

  Future<void> _saveLastUsedImage(String key, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, path);
  }

  Future<void> _loadInitialFaceImage(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/initial_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    setState(() {
      _faceImage = file;
    });
  }

  Future<void> _pickImage(ImageSource source, String imageType) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 1024);
      if (pickedFile != null) {
        setState(() {
          if (imageType == 'face') {
            _faceImage = File(pickedFile.path);
          } else if (imageType == 'shape') {
            _shapeImage = File(pickedFile.path);
            _saveLastUsedImage('lastShapeImagePath', pickedFile.path);
          } else if (imageType == 'color') {
            _colorImage = File(pickedFile.path);
            _saveLastUsedImage('lastColorImagePath', pickedFile.path);
          }
          _generatedSwapImageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showToast('Gagal memilih gambar: $e');
      }
    }
  }

  Future<void> _processSwap(String serverUrl) async {
    if (_faceImage == null || _shapeImage == null || _colorImage == null) {
      _showToast('Pastikan semua 3 gambar (Wajah, Bentuk, Warna) sudah dipilih!');
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedSwapImageBytes = null;
      _lastProcessInfo = null;
    });
    _startProgressAnimation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });

    final fullUrl = '$serverUrl/swap_hair';
    String? errorMessage;

    try {
      var request = http.MultipartRequest('POST', Uri.parse(fullUrl));
      request.files.add(await http.MultipartFile.fromPath('face_image', _faceImage!.path));
      request.files.add(await http.MultipartFile.fromPath('shape_image', _shapeImage!.path));
      request.files.add(await http.MultipartFile.fromPath('color_image', _colorImage!.path));
      request.fields['gender'] = _genderValue.toString();
      request.fields['age'] = _ageValue.toString();

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final imageBytes = await streamedResponse.stream.toBytes();
        if (mounted) {
          _stopProgressAnimation();
          _saveLastDuration(_stopwatch.elapsedMilliseconds);
          final durationInSeconds = (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);
          setState(() {
            _generatedSwapImageBytes = imageBytes;
            _lastProcessInfo = "$durationInSeconds detik";
          });
          Provider.of<HistoryProvider>(context, listen: false).addImageToHistory(imageBytes, 'hair_swap');
          _showToast('✅ Swap rambut berhasil!');
        }
      } else {
        final responseBody = await streamedResponse.stream.bytesToString();
        errorMessage = "Error: ${streamedResponse.reasonPhrase} | $responseBody";
      }
    } catch (e) {
      errorMessage = "Gagal terhubung ke server: $e";
    } finally {
      if (mounted) {
        _stopProgressAnimation();
        setState(() => _isLoading = false);
        if (errorMessage != null) {
          _showToast(errorMessage);
        }
      }
    }
  }

  void _showZoomableImage(dynamic imageSource, {Uint8List? imageBytesForSaving}) {
    ImageProvider? imageProvider;
    if (imageSource is File) {
      imageProvider = FileImage(imageSource);
    } else if (imageSource is Uint8List) {
      imageProvider = MemoryImage(imageSource);
    }
    if (imageProvider == null) return;

    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(ctx).pop()),
          actions: [
            if (imageBytesForSaving != null)
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () async {
                  await ImageGallerySaverPlus.saveImage(imageBytesForSaving);
                  if (!mounted) return;
                  _showToast("Gambar disimpan ke galeri!");
                },
              ),
          ],
        ),
        body: PhotoView(
          imageProvider: imageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cut, size: 24),
            SizedBox(width: 8),
            Text("Swap Rambut"),
          ],
        ),
        centerTitle: true,
      ),
      body: Consumer<NetworkDiscoveryProvider>(
        builder: (context, networkProvider, child) {
          if (networkProvider.state == DiscoveryState.found && networkProvider.serverAddress != null) {
            return _buildMainContent(networkProvider.serverAddress!);
          } else {
            return _buildConnectionStatusWidget(networkProvider);
          }
        },
      ),
    );
  }

  Widget _buildMainContent(String serverUrl) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      children: [
        Consumer<NetworkDiscoveryProvider>(builder: (context, provider, child) => _buildConnectionStatus(provider)),
        const SizedBox(height: 8),
        _buildImagePickerBox("Wajah (face)", _faceImage, (source) => _pickImage(source, 'face')),
        _buildImagePickerBox("Bentuk Rambut (shape)", _shapeImage, (source) => _pickImage(source, 'shape')),
        _buildImagePickerBox("Warna Rambut (color)", _colorImage, (source) => _pickImage(source, 'color')),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _isLoading ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.transform),
          label: const Text("Proses Swap Rambut"),
          onPressed: _isLoading || _faceImage == null || _shapeImage == null || _colorImage == null ? null : () => _processSwap(serverUrl),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 20),
        const Text("Hasil Akhir", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Center(
          child: _generatedSwapImageBytes != null && !_isLoading
              ? _buildResultBox()
              : _buildResultPlaceholder(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Center(
            child: (_isLoading || _lastProcessInfo != null)
                ? _buildLoadingIndicator(isComplete: !_isLoading)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBox() {
    bool hasImage = _generatedSwapImageBytes != null;
    return GestureDetector(
      onTap: hasImage
          ? () => _showZoomableImage(_generatedSwapImageBytes, imageBytesForSaving: _generatedSwapImageBytes)
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasImage
                ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.memory(_generatedSwapImageBytes!, fit: BoxFit.cover),
            )
                : null,
          ),
          if (hasImage)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.5), shape: BoxShape.circle),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator({required bool isComplete}) {
    final progressText = isComplete
        ? "Selesai dalam $_lastProcessInfo"
        : "Memproses... (${(_progressValue * 100).toStringAsFixed(0)}%)";

    final timerText = isComplete
        ? ""
        : "Estimasi: ${_estimatedDurationInMs ~/ 1000}s | Berjalan: ${_elapsedSeconds}s";

    return SizedBox(
      width: 250,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: isComplete ? 1.0 : _progressValue,
            backgroundColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Text(progressText),
          if (!isComplete) Text(timerText),
        ],
      ),
    );
  }

  Widget _buildResultPlaceholder() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text("Hasil akan muncul di sini", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildImagePickerBox(String title, File? imageFile, Function(ImageSource) onImagePicked) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: imageFile != null ? () => _showZoomableImage(imageFile) : null,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: imageFile != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.file(imageFile, fit: BoxFit.cover))
                        : const Icon(Icons.image, size: 30, color: Colors.grey),
                  ),
                  if (imageFile != null)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            IconButton(icon: const Icon(Icons.photo_library), onPressed: () => onImagePicked(ImageSource.gallery)),
            IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => onImagePicked(ImageSource.camera)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(NetworkDiscoveryProvider networkProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        const Expanded(
            child: Text(
              'Terhubung ke Server',
              style: TextStyle(color: Colors.green, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            )
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          iconSize: 20.0,
          onPressed: () {
            _showToast("Mencari ulang server...");
            networkProvider.discoverService();
          },
          tooltip: 'Cari Ulang Server',
        ),
      ],
    );
  }

  Widget _buildConnectionStatusWidget(NetworkDiscoveryProvider networkProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (networkProvider.state == DiscoveryState.searching) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Mencari server di jaringan...', textAlign: TextAlign.center),
            ] else ...[
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                  networkProvider.state == DiscoveryState.invalidFormat
                      ? 'Format IP/URL tidak valid di Pengaturan.'
                      : 'Server tidak ditemukan. Pastikan server berjalan di jaringan yang sama.',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => networkProvider.discoverService(),
                child: const Text('Coba Lagi'),
              )
            ]
          ],
        ),
      ),
    );
  }
}