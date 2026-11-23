import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attachment.dart';
import '../services/api_exception.dart';
import '../services/helpdesk_api.dart';
import '../utils/formatters.dart';
import 'ui.dart';

/// An attachment with its name, type and date (TKT-7). Images show a
/// thumbnail and open full screen when tapped.
///
/// Files are downloaded through the API client, so the request carries the
/// login token and an expired token is refreshed like any other request.
class AttachmentTile extends StatefulWidget {
  const AttachmentTile({super.key, required this.attachment});

  final Attachment attachment;

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final bytes = await context.read<HelpdeskApi>().downloadAttachment(widget.attachment.id);
      if (mounted) setState(() => _bytes = bytes);
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open() {
    final a = widget.attachment;
    if (!a.isImage) {
      showSnack(context, 'Open ${a.typeLabel} files on the HelpDesk Pro web app.');
      return;
    }
    final bytes = _bytes;
    if (bytes == null) {
      if (!_loading) _load();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ImageViewer(title: a.fileName, bytes: bytes),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final theme = Theme.of(context);
    final subtitle = [
      a.typeLabel,
      if (a.uploadedAt != null) formatDateTime(a.uploadedAt),
      if (a.uploadedByName != null) a.uploadedByName!,
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: _open,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 52,
          height: 52,
          color: theme.colorScheme.surfaceContainerHighest,
          child: _thumbnail(theme),
        ),
      ),
      title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _thumbnail(ThemeData theme) {
    if (!widget.attachment.isImage) {
      return Icon(Icons.insert_drive_file_outlined, color: theme.colorScheme.primary);
    }
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    if (_failed) return const Icon(Icons.refresh);
    return const Center(
      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.title, required this.bytes});

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(maxScale: 5, child: Image.memory(bytes)),
      ),
    );
  }
}
