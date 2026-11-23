import 'package:flutter/material.dart';

import '../models/insights.dart';
import '../theme.dart';

/// Reply box at the bottom of a ticket (REP-1). Staff also get an
/// "Internal note" switch (REP-2) and saved reply templates (REP-5).
/// The switch turns itself off after each note, so the next message is
/// customer-visible by default.
class ReplyComposer extends StatefulWidget {
  const ReplyComposer({
    super.key,
    required this.canPostInternal,
    required this.onSend,
    this.onAttach,
    this.loadTemplates,
  });

  final bool canPostInternal;

  /// Returns true when the message was sent, so the box can be cleared.
  final Future<bool> Function(String message, bool isInternal) onSend;
  final VoidCallback? onAttach;

  /// Shows the template picker and returns the chosen template.
  final Future<ReplyTemplate?> Function()? loadTemplates;

  @override
  State<ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<ReplyComposer> {
  final _controller = TextEditingController();
  bool _internal = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await widget.onSend(text, _internal);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent) {
        _controller.clear();
        _internal = false;
      }
    });
  }

  Future<void> _pickTemplate() async {
    final template = await widget.loadTemplates?.call();
    if (template == null || !mounted) return;
    _controller.text = template.body;
    _controller.selection = TextSelection.collapsed(offset: template.body.length);
  }

  @override
  Widget build(BuildContext context) {
    final internal = widget.canPostInternal && _internal;
    final canSend = _controller.text.trim().isNotEmpty && !_sending;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: internal ? AppColors.noteBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.canPostInternal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: FilterChip(
                          avatar: Icon(internal ? Icons.lock_rounded : Icons.lock_open_rounded,
                              size: 16, color: internal ? AppColors.noteInk : AppColors.muted),
                          label: const Text('Internal note', overflow: TextOverflow.ellipsis),
                          tooltip: 'Only staff can see internal notes',
                          selected: internal,
                          selectedColor: AppColors.noteBorder.withValues(alpha: 0.35),
                          onSelected: _sending ? null : (v) => setState(() => _internal = v),
                        ),
                      ),
                      const Spacer(),
                      if (widget.loadTemplates != null)
                        IconButton.filledTonal(
                          tooltip: 'Reply templates',
                          onPressed: _sending ? null : _pickTemplate,
                          icon: const Icon(Icons.bolt_rounded),
                        ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.onAttach != null)
                    IconButton(
                      tooltip: 'Add photo',
                      onPressed: _sending ? null : widget.onAttach,
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: internal ? 'Write a note only staff can see' : 'Write a reply',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(enabled: canSend, sending: _sending, internal: internal, onPressed: _send),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.sending, required this.internal, required this.onPressed});

  final bool enabled;
  final bool sending;
  final bool internal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: internal ? 'Add internal note' : 'Send reply',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || sending ? 1 : 0.45,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: internal ? null : AppColors.brand,
            color: internal ? AppColors.noteInk : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: sending
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
