import 'package:flutter/foundation.dart';

class ImageStateProvider with ChangeNotifier {
  Uint8List? _editedFaceImage;
  Uint8List? get editedFaceImage => _editedFaceImage;

  void setEditedFace(Uint8List imageBytes) {
    _editedFaceImage = imageBytes;
    notifyListeners();
  }

  void clearEditedFace() {
    _editedFaceImage = null;
    notifyListeners();
  }
}