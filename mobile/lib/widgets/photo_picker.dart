import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import 'ui.dart';

/// Asks "Camera or gallery?", then picks a photo (feature 10.3).
///
/// Photos are resized and compressed before upload. Returns null when the
/// user cancels or the photo is over the 5 MB limit (a message is shown).
Future<XFile?> pickTicketPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  try {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (photo == null || !context.mounted) return null;
    if (await photo.length() > AppConfig.maxAttachmentBytes) {
      if (context.mounted) {
        showSnack(context, 'That photo is larger than 5 MB. Please choose a smaller one.');
      }
      return null;
    }
    return photo;
  } on PlatformException {
    if (context.mounted) {
      final what = source == ImageSource.camera ? 'camera' : 'photo gallery';
      showSnack(context, 'Could not open the $what. Check the app permissions in Settings.');
    }
    return null;
  }
}
