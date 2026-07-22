import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../components/header.dart';
import 'manual_add.dart';
import 'bill_review.dart';
import '../services/bill_service.dart';
import '../components/loading_dialog.dart';
import '../themes/app_theme.dart';

class AddBillPage extends StatefulWidget {
  final String groupId;
  final List<Map<String, String>> members;

  const AddBillPage({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> with TickerProviderStateMixin {
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  final TextEditingController _billNameController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _billNameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (photo != null) {
        _fadeController.reset();
        setState(() => _capturedImage = File(photo.path));
        _fadeController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (photo != null) {
        _fadeController.reset();
        setState(() => _capturedImage = File(photo.path));
        _fadeController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_capturedImage == null) return;
    if (_billNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a bill name first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      LoadingDialog.show(
        context: context,
        title: 'Processing Bill',
        subtitle: 'Analysing receipt and extracting details...',
        icon: Icons.receipt_long,
        primaryColor: Theme.of(context).primaryColor,
      );

      final result = await BillService.uploadBill(
        imageFile: _capturedImage!,
        groupId: widget.groupId,
        billName: _billNameController.text.trim(),
      );

      if (!mounted) return;
      LoadingDialog.hide(context);

      if (result['success'] == true && result['expense'] != null) {
        final expense = result['expense'];
        final expenseId = expense['_id'] ?? expense['id'];
        if (expenseId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BillReviewPage(
                expenseId: expenseId,
                groupId: widget.groupId,
                members: widget.members,
                billImage: _capturedImage!,
              ),
            ),
          );
        } else {
          throw Exception('No expense ID received');
        }
      } else {
        throw Exception(result['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (!mounted) return;
      // Dismiss loading dialog if still showing.
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _retakePhoto() {
    _fadeController.reset();
    setState(() => _capturedImage = null);
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(title: 'Add Bill', heightFactor: 0.12),
          // Bill name field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _billNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Dinner at Café',
                    prefixIcon: Icon(Icons.receipt_outlined, size: 20, color: theme.primaryColor.withOpacity(0.7)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _capturedImage == null
                    ? _buildInitialView(isDark, theme)
                    : _buildPreviewView(isDark, theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView(bool isDark, ThemeData theme) {
    return Column(
      children: [
        // Camera placeholder card
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? theme.primaryColor.withOpacity(0.2)
                    : theme.primaryColor.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 52,
                    color: theme.primaryColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No image selected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a photo or pick from gallery',
                  style: TextStyle(
                    fontSize: 13,
                    color: (theme.textTheme.bodySmall?.color ?? Colors.grey).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Take Photo
        _actionButton(
          icon: Icons.camera_alt,
          label: 'Take Photo',
          onPressed: _takePhoto,
          isPrimary: true,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Gallery + Manual row
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onPressed: _pickFromGallery,
                isPrimary: false,
                theme: theme,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                icon: Icons.edit_outlined,
                label: 'Manual Add',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManuallyAddPage(
                        groupId: widget.groupId,
                        members: widget.members,
                      ),
                    ),
                  );
                },
                isPrimary: false,
                theme: theme,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewView(bool isDark, ThemeData theme) {
    return Column(
      children: [
        // Image preview
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: FileImage(_capturedImage!),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              // Retake overlay button (top-right)
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _isUploading ? null : _retakePhoto,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.refresh, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Retake', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Upload & Parse button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadImage,
            icon: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 22),
            label: Text(
              _isUploading ? 'Processing...' : 'Upload & Parse',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: theme.primaryColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
    required ThemeData theme,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                elevation: 0,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primaryColor,
                side: BorderSide(color: theme.primaryColor.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
    );
  }
}
