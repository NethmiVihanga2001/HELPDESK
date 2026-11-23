import 'json_utils.dart';

/// A file attached to a ticket or reply (TKT-7).
class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    this.mimeType,
    this.uploadedAt,
    this.uploadedByName,
  });

  factory Attachment.fromJson(Json json) => Attachment(
        id: readString(json['id']),
        fileName: readString(json['fileName'] ?? json['name'], 'file'),
        mimeType: (json['mimeType'] ?? json['fileType'] ?? json['type'])
            ?.toString(),
        uploadedAt: readDate(json['uploadedAt'] ?? json['createdAt']),
        uploadedByName: readRelationName(json, 'uploadedBy'),
      );

  final String id;
  final String fileName;
  final String? mimeType;
  final DateTime? uploadedAt;
  final String? uploadedByName;

  static final _imageExtension =
      RegExp(r'\.(jpe?g|png|gif|webp|heic|bmp)$', caseSensitive: false);

  bool get isImage {
    final mime = mimeType;
    if (mime != null && mime.contains('/')) return mime.startsWith('image/');
    return _imageExtension.hasMatch(fileName);
  }

  /// Short type label such as "JPG" or "PDF".
  String get typeLabel {
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0 && dot < fileName.length - 1) {
      return fileName.substring(dot + 1).toUpperCase();
    }
    return isImage ? 'Image' : 'File';
  }
}
