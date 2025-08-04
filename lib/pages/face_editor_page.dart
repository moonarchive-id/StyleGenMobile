import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:photo_view/photo_view.dart';
import '../providers/network_discovery_provider.dart';
import '../providers/history_provider.dart';
import '../providers/image_state_provider.dart';

class FaceEditorPage extends StatefulWidget {
  const FaceEditorPage({super.key});

  @override
  State<FaceEditorPage> createState() => _FaceEditorPageState();
}

class _FaceEditorPageState extends State<FaceEditorPage> with AutomaticKeepAliveClientMixin {
  File? _faceImage;
  Uint8List? _editedImageBytes;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  late Map<String, _SliderControl> _sliderControls;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeSliders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermissionAndDiscover();
      _loadLastUsedImage();
    });
  }

  void _initializeSliders() {
    _sliderControls = {
      'skin': _SliderControl(label: "Tekstur Kulit", minLabel: "Tajam", maxLabel: "Halus"),
      'eyes': _SliderControl(label: "Ukuran Mata", minLabel: "Kecil", maxLabel: "Besar"),
      'lips': _SliderControl(label: "Ukuran Bibir", minLabel: "Tipis", maxLabel: "Tebal"),
      'nose_bridge': _SliderControl(label: "Batang Hidung", minLabel: "Ramping", maxLabel: "Lebar"),
      'nose_tip': _SliderControl(label: "Ujung Hidung", minLabel: "Ramping", maxLabel: "Lebar"),
      'forehead_width': _SliderControl(label: "Lebar Dahi", minLabel: "Ramping", maxLabel: "Lebar"),
      'forehead_height': _SliderControl(label: "Tinggi Dahi", minLabel: "Pendek", maxLabel: "Tinggi"),
      'jaw': _SliderControl(label: "Bentuk Dagu", minLabel: "Tajam", maxLabel: "Lebar"),
    };
  }

  void _resetSliders() {
    setState(() {
      for (var control in _sliderControls.values) {
        control.value = 0.0;
      }
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _loadLastUsedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastImagePath = prefs.getString('lastFaceImagePath');
    if (lastImagePath != null && File(lastImagePath).existsSync()) {
      setState(() {
        _faceImage = File(lastImagePath);
      });
    }
  }

  Future<void> _saveLastUsedImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastFaceImagePath', path);
  }

  Future<void> _requestLocationPermissionAndDiscover() async {
    var status = await Permission.location.request();
    if (!mounted) return;
    if (status.isGranted) {
      Provider.of<NetworkDiscoveryProvider>(context, listen: false).discoverService();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izin lokasi diperlukan untuk menemukan server di jaringan lokal.'),
          action: SnackBarAction(label: 'Buka Pengaturan', onPressed: openAppSettings),
        ),
      );
      Provider.of<NetworkDiscoveryProvider>(context, listen: false).setErrorState();
    }
  }

  Future<void> _pickFaceImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 1024);
      if (pickedFile != null) {
        setState(() {
          _faceImage = File(pickedFile.path);
          _editedImageBytes = null;
        });
        await _saveLastUsedImage(pickedFile.path);
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('Gagal memilih gambar: $e');
    }
  }

  Future<void> _processFaceEdit(String serverUrl) async {
    if (_faceImage == null) {
      _showToast('Harap pilih foto wajah untuk diedit!');
      return;
    }

    setState(() {
      _isLoading = true;
      _editedImageBytes = null;
    });
    final fullUrl = '$serverUrl/preview_face';
    String? errorMessage;

    try {
      var request = http.MultipartRequest('POST', Uri.parse(fullUrl));
      request.files.add(await http.MultipartFile.fromPath('face_image', _faceImage!.path));
      for (var entry in _sliderControls.entries) {
        request.fields['p_${entry.key}'] = entry.value.value.toString();
      }

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final imageBytes = await streamedResponse.stream.toBytes();
        if (mounted) {
          setState(() => _editedImageBytes = imageBytes);
          Provider.of<HistoryProvider>(context, listen: false).addImageToHistory(imageBytes, 'face_editor');
          Provider.of<ImageStateProvider>(context, listen: false).setEditedFace(imageBytes);
          _showToast("✅ Wajah berhasil diedit!");
        }
      } else {
        final responseBody = await streamedResponse.stream.bytesToString();
        errorMessage = "Error: ${streamedResponse.reasonPhrase} - $responseBody";
      }
    } catch (e) {
      errorMessage = "Gagal terhubung ke server: $e";
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (errorMessage != null) {
        _showToast(errorMessage);
      }
    }
  }

  void _sendToHairSwap() {
    if (_editedImageBytes != null) {
      Provider.of<ImageStateProvider>(context, listen: false).setEditedFace(_editedImageBytes!);
      DefaultTabController.of(context).animateTo(1);
      _showToast("➡️ Gambar dikirim ke Swap Rambut");
    } else {
      _showToast("Harap edit wajah terlebih dahulu!");
    }
  }

  void _showZoomableImage(ImageProvider imageProvider, Uint8List? imageBytes) {
    if (imageBytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () async {
                  await ImageGallerySaverPlus.saveImage(imageBytes);
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
      ),
    );
  }

  Future<void> _showValueInputDialog(String controlKey, _SliderControl control) async {
    final textController = TextEditingController(text: control.value.toStringAsFixed(1));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Setel Nilai ${control.label}'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(
            hintText: 'Contoh: 5.5 atau -10',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.of(ctx).pop(textController.text), child: const Text("OK")),
        ],
      ),
    );

    if (result != null) {
      final newValue = double.tryParse(result) ?? control.value;
      setState(() {
        control.value = newValue.clamp(-15.0, 15.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_fix_high, size: 24),
              SizedBox(width: 8),
              Text("Editor Wajah"),
            ],
          ),
          centerTitle: true
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
      padding: const EdgeInsets.all(16.0),
      children: [
        Consumer<NetworkDiscoveryProvider>(builder: (context, provider, child) => _buildConnectionStatus(provider)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildImageDisplay("Gambar Asli", _faceImage, _faceImage?.readAsBytesSync()),
            _buildImageDisplay("Hasil Edit", _editedImageBytes, _editedImageBytes, isLoading: _isLoading),
          ],
        ),
        const SizedBox(height: 16),
        _buildImagePickerButtons(),
        const SizedBox(height: 16),
        const Divider(),
        _buildSlidersSection(),
        const SizedBox(height: 20),
        _buildActionButtons(serverUrl),
      ],
    );
  }

  Widget _buildImageDisplay(String title, dynamic imageSource, Uint8List? imageBytes, {bool isLoading = false}) {
    ImageProvider? imageProvider;
    if (imageSource is File) {
      imageProvider = FileImage(imageSource);
    } else if (imageSource is Uint8List) {
      imageProvider = MemoryImage(imageSource);
    }

    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: imageProvider == null || isLoading ? null : () => _showZoomableImage(imageProvider!, imageBytes),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.width * 0.4,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              image: imageProvider != null && !isLoading ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isLoading)
                  const CircularProgressIndicator(),
                if (!isLoading && imageProvider == null)
                  const Center(child: Icon(Icons.image_search, size: 40, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text("Tap gambar untuk zoom", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildImagePickerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text("Pilih Gambar"),
          onPressed: () => _pickFaceImage(ImageSource.gallery),
        ),
        const SizedBox(width: 16),
        TextButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text("Ambil Foto"),
          onPressed: () => _pickFaceImage(ImageSource.camera),
        ),
      ],
    );
  }

  Widget _buildSlidersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Kontrol Editor Wajah", style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text("Reset"),
              onPressed: _resetSliders,
            )
          ],
        ),
        const SizedBox(height: 8),
        ..._sliderControls.entries.map((entry) {
          return _buildSlider(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildSlider(String controlKey, _SliderControl control) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5.0),
        Row(
          children: [
            Expanded(
              child: Text(control.label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            InkWell(
              onTap: () => _showValueInputDialog(controlKey, control),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  control.value.toStringAsFixed(1),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20.0),
          ],
        ),
        Slider(
          value: control.value, min: -15.0, max: 15.0, divisions: 300,
          onChanged: (v) => setState(() => control.value = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(control.minLabel, style: Theme.of(context).textTheme.bodySmall),
              Text(control.maxLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionButtons(String serverUrl) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            icon: _isLoading ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.auto_fix_high),
            label: const Text("Edit Wajah Ini"),
            onPressed: _isLoading || _faceImage == null ? null : () => _processFaceEdit(serverUrl),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Kirim ke Swap"),
            onPressed: _isLoading || _editedImageBytes == null ? null : _sendToHairSwap,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary),
          ),
        ),
      ],
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

class _SliderControl {
  final String label;
  final String minLabel;
  final String maxLabel;
  double value;

  _SliderControl({
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    this.value = 0.0,
  });
}