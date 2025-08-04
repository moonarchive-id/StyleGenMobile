import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerBox extends StatelessWidget {
  final String title;
  final File? imageFile;
  final Uint8List? imageBytes;
  final Function(File) onImagePicked;
  final ImagePicker _picker = ImagePicker();

  ImagePickerBox({
    super.key,
    required this.title,
    this.imageFile,
    this.imageBytes,
    required this.onImagePicked,
  });

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1024);
      if (pickedFile != null) {
        onImagePicked(File(pickedFile.path));
      }
    } catch (e) {
      // Handle error, maybe show a snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: imageBytes != null
                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                    : imageFile != null
                    ? Image.file(imageFile!, fit: BoxFit.cover)
                    : Icon(Icons.image, size: 40, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.secondary),
              onPressed: () => _pickImage(ImageSource.gallery),
              tooltip: 'Pilih dari Galeri',
            ),
            IconButton(
              icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
              onPressed: () => _pickImage(ImageSource.camera),
              tooltip: 'Ambil dari Kamera',
            ),
          ],
        ),
      ),
    );
  }
}