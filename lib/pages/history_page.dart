import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../providers/history_provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSelectionMode = false;
  final Set<File> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false).loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleSelection(File imageFile) {
    setState(() {
      if (_selectedImages.contains(imageFile)) {
        _selectedImages.remove(imageFile);
      } else {
        _selectedImages.add(imageFile);
      }
      _isSelectionMode = _selectedImages.isNotEmpty;
    });
  }

  void _deleteSelectedImages() async {
    final int count = _selectedImages.length;
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    await historyProvider.deleteImages(_selectedImages);
    setState(() {
      _selectedImages.clear();
      _isSelectionMode = false;
    });
    _showToast('$count gambar dihapus.');
  }

  void _viewImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(ctx).pop()),
          actions: [
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () async {
                await ImageGallerySaverPlus.saveImage(imageBytes);
                _showToast("Gambar disimpan ke galeri!");
              },
            ),
          ],
        ),
        body: PhotoView(
          imageProvider: FileImage(imageFile),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    ));
  }

  AppBar _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        title: Text('${_selectedImages.length} dipilih'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelectionMode = false;
            _selectedImages.clear();
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteSelectedImages,
          ),
        ],
      );
    } else {
      return AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history),
            SizedBox(width: 8),
            Text('Riwayat'),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_fix_high), text: 'Editor Wajah'),
            Tab(icon: Icon(Icons.cut), text: 'Swap Rambut'),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<HistoryProvider>(
        builder: (context, historyProvider, child) {
          if (historyProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryGrid(historyProvider.faceHistoryImages),
              _buildHistoryGrid(historyProvider.swapHistoryImages),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryGrid(List<File> images) {
    if (images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Riwayat di sini masih kosong.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final imageFile = images[index];
        final isSelected = _selectedImages.contains(imageFile);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(imageFile);
            } else {
              _viewImage(imageFile);
            }
          },
          onLongPress: () {
            _toggleSelection(imageFile);
          },
          child: GridTile(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.red);
                    },
                  ),
                ),
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}