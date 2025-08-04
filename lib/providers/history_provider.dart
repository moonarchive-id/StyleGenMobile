import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class HistoryProvider with ChangeNotifier {
  List<File> _faceHistoryImages = [];
  List<File> get faceHistoryImages => _faceHistoryImages;

  List<File> _swapHistoryImages = [];
  List<File> get swapHistoryImages => _swapHistoryImages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory(path.join(directory.path, 'history'));

      if (await historyDir.exists()) {
        final files = await historyDir.list().toList();
        _faceHistoryImages.clear();
        _swapHistoryImages.clear();

        for (var file in files.whereType<File>()) {
          if (path.basename(file.path).startsWith('face_editor_')) {
            _faceHistoryImages.add(file);
          } else if (path.basename(file.path).startsWith('hair_swap_')) {
            _swapHistoryImages.add(file);
          }
        }

        _faceHistoryImages.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        _swapHistoryImages.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      } else {
        _faceHistoryImages = [];
        _swapHistoryImages = [];
      }
    } catch (e) {
      _faceHistoryImages = [];
      _swapHistoryImages = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addImageToHistory(Uint8List imageBytes, String type) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyDir = Directory(path.join(directory.path, 'history'));

      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(historyDir.path, '${type}_$timestamp.jpg');

      final imageFile = File(filePath);
      await imageFile.writeAsBytes(imageBytes);

      await loadHistory();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteImages(Set<File> imagesToDelete) async {
    if (imagesToDelete.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      for (final file in imagesToDelete) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // Handle error
    }

    await loadHistory();
  }
}