import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Bottom sheet dialog for choosing image source: Camera or Gallery.
class ImageSourcePicker {
  static Future<XFile?> show(BuildContext context) async {
    final picker = ImagePicker();
    XFile? result;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Image Source',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.orange),
                title: const Text('Camera'),
                onTap: () async {
                  result = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.orange),
                title: const Text('Gallery'),
                onTap: () async {
                  result = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1024,
                    maxHeight: 1024,
                    imageQuality: 85,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );

    return result;
  }
}
