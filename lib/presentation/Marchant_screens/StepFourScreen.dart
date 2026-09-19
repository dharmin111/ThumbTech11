// lib/presentation/Merchant/StepFourScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'StepFiveScreen.dart';

class StepFourScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const StepFourScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<StepFourScreen> createState() => _StepFourScreenState();
}

class _StepFourScreenState extends State<StepFourScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _images = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = true;
  bool _isUploading = false;

  final tealColor = const Color(0xFF006B6B);

  @override
  void initState() {
    super.initState();
    // ✅ Load images AFTER first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingImages();
    });
  }

  // ✅ Load existing images from Firestore
  Future<void> _loadExistingImages() async {
    setState(() => _isLoading = true);

    try {
      print('📥 Loading images for userId: ${widget.userId}');

      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final urls = data['storePhotoUrls'] as List<dynamic>?;

        print('📥 Found ${urls?.length ?? 0} images in Firestore');

        if (urls != null && urls.isNotEmpty) {
          setState(() {
            _existingImageUrls = urls.map((e) => e.toString()).toList();
          });
          print('✅ Loaded ${_existingImageUrls.length} existing images');
        }
      } else {
        print('❌ Merchant document does not exist');
      }
    } catch (e) {
      print('❌ Error loading images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Show Bottom Sheet for Image Source Selection
  Future<void> _showImageSourceDialog() async {
    final totalImages = getTotalImagesCount();
    if (totalImages >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 photos already uploaded'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMultipleImages();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You can select multiple images from gallery',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: tealColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tealColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: tealColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: tealColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        final totalImages = getTotalImagesCount();
        if (totalImages >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 photos allowed'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        setState(() {
          _images.add(File(image.path));
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final totalImages = getTotalImagesCount();
      final remaining = 5 - totalImages;

      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 photos already uploaded'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        int addedCount = 0;
        for (var image in images) {
          final currentTotal = getTotalImagesCount();
          if (currentTotal >= 5) break;
          setState(() {
            _images.add(File(image.path));
            addedCount++;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $addedCount photo(s) added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error picking multiple images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  int getTotalImagesCount() {
    return _existingImageUrls.length + _images.length;
  }

  Future<void> _uploadImagesAndProceed() async {
    if (getTotalImagesCount() < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload ${5 - getTotalImagesCount()} more photo(s)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ If no new images, just proceed
    if (_images.isEmpty) {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .update({
        'status': 'waiting',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'merchantStatus': 'waiting',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StepFiveScreen(
              userId: widget.userId,
              userEmail: widget.userEmail,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _isLoading = true;
    });

    try {
      List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        final file = _images[i];
        final ref = FirebaseStorage.instance
            .ref()
            .child('merchants/${widget.userId}/store_photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      final allUrls = [..._existingImageUrls, ...imageUrls];

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .update({
        'storePhotoUrls': allUrls,
        'status': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'merchantStatus': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StepFiveScreen(
              userId: widget.userId,
              userEmail: widget.userEmail,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Loading Screen
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final totalImages = getTotalImagesCount();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ Top Image
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/Step/stepFour.PNG',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Image not found',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ Upload Area - Photos Grid
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: totalImages >= 5 ? Colors.green.shade300 : Colors.grey.shade300,
                      width: totalImages >= 5 ? 2 : 1,
                    ),
                  ),
                  child: _images.isEmpty && _existingImageUrls.isEmpty
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 50,
                        color: tealColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload store photos',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Select multiple images from gallery',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                      : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: totalImages > 5 ? 5 : totalImages,
                    itemBuilder: (context, index) {
                      final isExisting = index < _existingImageUrls.length;
                      final imageIndex = isExisting ? index : index - _existingImageUrls.length;

                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: isExisting
                                    ? NetworkImage(_existingImageUrls[imageIndex])
                                    : FileImage(_images[imageIndex]) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // ✅ Checkmark for existing images
                          if (isExisting)
                            Positioned(
                              left: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // ✅ Remove button for new images
                          if (!isExisting)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: GestureDetector(
                                onTap: () => _removeImage(imageIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ✅ Photo Count with Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalImages / 5 photos uploaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: totalImages >= 5 ? Colors.green.shade700 : tealColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 150,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: totalImages / 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: totalImages >= 5 ? Colors.green : tealColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (totalImages < 5)
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: tealColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: tealColor),
                            Text(
                              'Add More',
                              style: TextStyle(
                                fontSize: 12,
                                color: tealColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ Step Indicator + Button
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStepIndicator(1, true, tealColor),
                      _buildStepIndicator(2, true, tealColor),
                      _buildStepIndicator(3, true, tealColor),
                      _buildStepIndicator(4, true, tealColor),
                      _buildStepIndicator(5, false, tealColor),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (totalImages < 5 || _isUploading) ? null : _uploadImagesAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: totalImages >= 5 ? tealColor : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: totalImages >= 5 ? 3 : 0,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 20),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: Text(
                                    totalImages >= 5
                                        ? 'Upload & Continue'
                                        : '${5 - totalImages} more photos needed',
                                    style: TextStyle(
                                      fontSize: totalImages >= 5 ? 18 : 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (totalImages >= 5)
                                  Positioned(
                                    right: 0,
                                    child: const Icon(
                                      Icons.arrow_forward,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive, Color tealColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? tealColor : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: tealColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : null,
        border: isActive
            ? Border.all(
          color: tealColor.withOpacity(0.3),
          width: 2,
        )
            : null,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}