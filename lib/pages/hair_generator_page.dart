// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter/foundation.dart';
// import '../providers/network_discovery_provider.dart';
// import '../providers/history_provider.dart';
//
// class HairGeneratorPage extends StatefulWidget {
//   const HairGeneratorPage({super.key});
//
//   @override
//   State<HairGeneratorPage> createState() => _HairGeneratorPageState();
// }
//
// class _HairGeneratorPageState extends State<HairGeneratorPage> {
//   File? _faceImage;
//   File? _styleImage;
//   File? _colorImage;
//
//   Uint8List? _generatedImageBytes;
//   bool _isLoading = false;
//   final ImagePicker _picker = ImagePicker();
//
//   double _genValue = 0.0;
//   double _ageValue = 0.0;
//   double _hairValue = 0.0;
//   double _faceValue = 0.0;
//   double _lightingValue = 0.0;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _requestLocationPermissionAndDiscover();
//     });
//   }
//
//   Future<void> _requestLocationPermissionAndDiscover() async {
//     var status = await Permission.location.request();
//
//     if (status.isGranted) {
//       if (mounted) {
//         Provider.of<NetworkDiscoveryProvider>(context, listen: false).discoverService();
//       }
//     } else {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Izin lokasi diperlukan untuk menemukan server di jaringan lokal.'),
//             action: SnackBarAction(
//               label: 'Buka Pengaturan',
//               onPressed: openAppSettings,
//             ),
//           ),
//         );
//         Provider.of<NetworkDiscoveryProvider>(context, listen: false).setErrorState();
//       }
//     }
//   }
//
//   Future<void> _pickImage(ImageSource source, String imageType) async {
//     try {
//       final pickedFile = await _picker.pickImage(source: source);
//       if (pickedFile != null) {
//         setState(() {
//           if (imageType == 'face') {
//             _faceImage = File(pickedFile.path);
//           } else if (imageType == 'style') {
//             _styleImage = File(pickedFile.path);
//           } else if (imageType == 'color') {
//             _colorImage = File(pickedFile.path);
//           }
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Gagal memilih gambar: $e')),
//         );
//       }
//     }
//   }
//
//   Future<void> _processImage(String serverUrl, String endpoint) async {
//     if (endpoint == '/preview_face') {
//       if (_faceImage == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Harap pilih foto wajah untuk preview!')),
//         );
//         return;
//       }
//     } else if (endpoint == '/swap_hair') {
//       if (_faceImage == null || _styleImage == null || _colorImage == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Harap pilih foto wajah, gaya, dan warna rambut untuk swap!')),
//         );
//         return;
//       }
//     }
//
//     setState(() {
//       _isLoading = true;
//       _generatedImageBytes = null;
//     });
//
//     final fullUrl = '$serverUrl$endpoint';
//
//     try {
//       var request = http.MultipartRequest('POST', Uri.parse(fullUrl));
//
//       request.files.add(await http.MultipartFile.fromPath('face_image', _faceImage!.path));
//       if (endpoint == '/swap_hair') {
//         request.files.add(await http.MultipartFile.fromPath('shape_image', _styleImage!.path));
//         request.files.add(await http.MultipartFile.fromPath('color_image', _colorImage!.path));
//       }
//
//       request.fields['gen'] = _genValue.toString();
//       request.fields['age'] = _ageValue.toString();
//       request.fields['hair'] = _hairValue.toString();
//       request.fields['face'] = _faceValue.toString();
//       request.fields['lighting'] = _lightingValue.toString();
//
//       var streamedResponse = await request.send();
//
//       if (streamedResponse.statusCode == 200) {
//         final imageBytes = await streamedResponse.stream.toBytes();
//         setState(() {
//           _generatedImageBytes = imageBytes;
//         });
//
//         if(mounted) {
//           await Provider.of<HistoryProvider>(context, listen: false)
//               .addImageToHistory(imageBytes);
//
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('✨ ${endpoint == '/preview_face' ? 'Preview' : 'Swap'} berhasil dibuat dan disimpan ke riwayat!')),
//           );
//         }
//
//       } else if (streamedResponse.statusCode == 503) {
//         final responseBody = await streamedResponse.stream.bytesToString();
//         if(mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Model AI belum siap: $responseBody')),
//           );
//         }
//       }
//       else {
//         final responseBody = await streamedResponse.stream.bytesToString();
//         if(mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error dari server: ${streamedResponse.reasonPhrase} | $responseBody')),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Gagal terhubung ke server: $e')),
//         );
//       }
//     } finally {
//       if(mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Aileen's Hair Magic ❤️"),
//         centerTitle: true,
//       ),
//       body: Consumer<NetworkDiscoveryProvider>(
//         builder: (context, networkProvider, child) {
//           if (networkProvider.state == DiscoveryState.found && networkProvider.serverAddress != null && networkProvider.serverAddress!.isNotEmpty) {
//             return _buildMainContent(networkProvider.serverAddress!, networkProvider);
//           } else {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (networkProvider.state == DiscoveryState.searching) ...[
//                     const CircularProgressIndicator(),
//                     const SizedBox(height: 16),
//                     const Text('Mencari server di jaringan...'),
//                   ] else if (networkProvider.state == DiscoveryState.notFound || networkProvider.state == DiscoveryState.error || networkProvider.state == DiscoveryState.invalidFormat) ...[
//                     const Icon(Icons.error_outline, color: Colors.red, size: 48),
//                     const SizedBox(height: 16),
//                     Text(
//                         networkProvider.state == DiscoveryState.invalidFormat
//                             ? 'Format IP/URL tidak valid. Mohon periksa Pengaturan.'
//                             : 'Server tidak ditemukan. Coba lagi atau periksa Pengaturan.',
//                         textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)
//                     ),
//                     const SizedBox(height: 8),
//                     ElevatedButton(
//                       onPressed: () => networkProvider.discoverService(),
//                       child: const Text('Coba Lagi'),
//                     )
//                   ] else ...[
//                     const CircularProgressIndicator(),
//                     const SizedBox(height: 16),
//                     const Text('Memulai koneksi server...'),
//                   ]
//                 ],
//               ),
//             );
//           }
//         },
//       ),
//     );
//   }
//
//   Widget _buildMainContent(String serverUrl, NetworkDiscoveryProvider networkProvider) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16.0),
//       child: Center(
//         child: Column(
//           children: [
//             _buildConnectionStatus(networkProvider),
//             const SizedBox(height: 16),
//
//             const Text("1. Pilih Gambar Input", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             _buildImagePickerBox("Wajah (Preview & Swap)", _faceImage, (source, type) => _pickImage(source, type), 'face'),
//             _buildImagePickerBox("Gaya Rambut (Swap)", _styleImage, (source, type) => _pickImage(source, type), 'style'),
//             _buildImagePickerBox("Warna Rambut (Swap)", _colorImage, (source, type) => _pickImage(source, type), 'color'),
//
//             const SizedBox(height: 20),
//             const Text("2. Atur Atribut (Slider)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             _buildSlider("Gender", _genValue, (newValue) { setState(() => _genValue = newValue); }),
//             _buildSlider("Usia", _ageValue, (newValue) { setState(() => _ageValue = newValue); }),
//             _buildSlider("Rambut", _hairValue, (newValue) { setState(() => _hairValue = newValue); }),
//             _buildSlider("Bentuk Wajah", _faceValue, (newValue) { setState(() => _faceValue = newValue); }),
//             _buildSlider("Pencahayaan", _lightingValue, (newValue) { setState(() => _lightingValue = newValue); }),
//
//             const SizedBox(height: 20),
//             const Text("3. Pilih Operasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Expanded(
//                   child: _isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : ElevatedButton.icon(
//                     icon: const Icon(Icons.face),
//                     label: const Text("Preview Wajah"),
//                     onPressed: _faceImage == null ? null : () => _processImage(serverUrl, '/preview_face'),
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: _isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : ElevatedButton.icon(
//                     icon: const Icon(Icons.transform),
//                     label: const Text("Swap Rambut"),
//                     onPressed: _faceImage == null || _styleImage == null || _colorImage == null ? null : () => _processImage(serverUrl, '/swap_hair'),
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 30),
//             const Text("4. Hasil Ajaib", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 10),
//             Container(
//               width: 250,
//               height: 250,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade400),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: _generatedImageBytes != null
//                   ? ClipRRect(
//                 borderRadius: BorderRadius.circular(11),
//                 child: Image.memory(_generatedImageBytes!, fit: BoxFit.cover),
//               )
//                   : const Center(
//                 child: Text("Hasil akan muncul di sini", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Column(
//         children: [
//           Text('$label: ${value.toStringAsFixed(1)}', style: const TextStyle(fontSize: 16)),
//           Slider(
//             value: value,
//             min: -5.0,
//             max: 5.0,
//             divisions: 100,
//             onChanged: onChanged,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildConnectionStatus(NetworkDiscoveryProvider networkProvider) {
//     IconData icon;
//     Color color;
//     String message;
//
//     if (networkProvider.state == DiscoveryState.found) {
//       icon = Icons.check_circle_outline;
//       color = Colors.green;
//       message = 'Terhubung ke server.';
//     } else if (networkProvider.state == DiscoveryState.notFound || networkProvider.state == DiscoveryState.error) {
//       icon = Icons.cancel;
//       color = Colors.red;
//       message = 'Gagal terhubung ke server.';
//     } else if (networkProvider.state == DiscoveryState.invalidFormat) {
//       icon = Icons.warning_amber;
//       color = Colors.orange;
//       message = 'Format IP/URL tidak valid.';
//     } else if (networkProvider.state == DiscoveryState.searching) {
//       icon = Icons.info_outline;
//       color = Theme.of(context).colorScheme.primary;
//       message = 'Sedang mencari server...';
//     } else {
//       icon = Icons.info_outline;
//       color = Colors.grey;
//       message = 'Status koneksi tidak diketahui. Periksa Pengaturan.';
//     }
//
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, color: color, size: 20),
//         const SizedBox(width: 8),
//         Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 14))),
//       ],
//     );
//   }
//
//   Widget _buildImagePickerBox(String title, File? imageFile, Function(ImageSource, String) onImagePicked, String imageType) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Container(
//             width: 80,
//             height: 80,
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: imageFile != null
//                 ? ClipRRect(
//               borderRadius: BorderRadius.circular(7),
//               child: Image.file(imageFile, fit: BoxFit.cover),
//             )
//                 : const Icon(Icons.image, size: 40, color: Colors.grey),
//           ),
//           const SizedBox(width: 10),
//           Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
//           IconButton(
//             icon: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
//             onPressed: () => onImagePicked(ImageSource.gallery, imageType),
//             tooltip: 'Pilih dari Galeri',
//           ),
//           IconButton(
//             icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
//             onPressed: () => onImagePicked(ImageSource.camera, imageType),
//             tooltip: 'Ambil dari Kamera',
//           ),
//         ],
//       ),
//     );
//   }
// }