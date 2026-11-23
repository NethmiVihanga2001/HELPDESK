import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../models/lookups.dart';
import '../models/ticket.dart';
import '../services/api_exception.dart';
import '../services/helpdesk_api.dart';
import '../services/ticket_events.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/photo_picker.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import 'article_screen.dart';

/// TKT-1: title, description, category, priority and an optional photo.
/// While the title is typed, matching help articles are suggested (KB-3).
/// Pops with the new [Ticket].
class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  Timer? _debounce;

  List<TicketCategory> _categories = const [];
  List<TicketPriority> _priorities = const [];
  List<Article> _suggestions = const [];
  bool _loadingLists = true;
  String? _listsError;

  String? _categoryId;
  String? _priorityId;
  bool _categoryMissing = false;
  XFile? _photo;

  bool _submitting = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() {
      _loadingLists = true;
      _listsError = null;
    });
    final api = context.read<HelpdeskApi>();
    try {
      final results = await Future.wait<Object>([api.getCategories(), api.getPriorities()]);
      if (!mounted) return;
      final priorities = results[1] as List<TicketPriority>;
      setState(() {
        _categories = results[0] as List<TicketCategory>;
        _priorities = priorities;
        _priorityId ??= priorities.where((p) => p.level == PriorityLevel.medium).firstOrNull?.id ?? priorities.firstOrNull?.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _listsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  void _onTitleChanged(String text) {
    _clearFieldError('title');
    _debounce?.cancel();
    if (text.trim().length < 4) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final found = await context.read<HelpdeskApi>().getArticles(search: text);
        if (mounted) setState(() => _suggestions = found.where((a) => a.published).take(3).toList());
      } on ApiException {
        // Suggestions are optional; ignore failures.
      }
    });
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) setState(() => _fieldErrors = Map.of(_fieldErrors)..remove(field));
  }

  Future<void> _addPhoto() async {
    final photo = await pickTicketPhoto(context);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    setState(() => _categoryMissing = _categoryId == null);
    if (!valid || _categoryId == null || _priorityId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final api = context.read<HelpdeskApi>();
    final events = context.read<TicketEvents>();

    final Ticket ticket;
    try {
      ticket = await api.createTicket(
        title: _title.text.trim(),
        description: _description.text.trim(),
        categoryId: _categoryId!,
        priorityId: _priorityId!,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = e.fieldErrors;
        const formFields = {'title', 'description'};
        _error = e.fieldErrors.keys.any(formFields.contains) ? null : e.message;
      });
      return;
    }

    // The ticket exists now. A failed photo upload must not hide that.
    String? photoError;
    final photo = _photo;
    if (photo != null) {
      try {
        await api.uploadAttachment(ticket.id, filePath: photo.path, fileName: photo.name);
      } on ApiException catch (e) {
        photoError = e.message;
      }
    }
    events.changed();
    if (!mounted) return;
    if (photoError != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Ticket ${ticket.number} created'),
          content: Text('The photo could not be uploaded: $photoError\n\nYou can add it again from the ticket screen.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop(ticket);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            child: HeaderBar(showBack: true, title: 'New ticket', subtitle: "Tell us what's going on"),
          ),
          Expanded(
            child: _loadingLists
                ? const SkeletonList(count: 4, itemHeight: 120)
                : _listsError != null
                    ? ErrorView(message: _listsError!, onRetry: _loadLists)
                    : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          FadeSlideIn(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    maxLength: 150,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Short summary of the problem',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    forceErrorText: _fieldErrors['title'],
                    onChanged: _onTitleChanged,
                    validator: Validators.ticketTitle,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _suggestions.isEmpty ? const SizedBox(width: double.infinity) : _SuggestionBox(articles: _suggestions),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What happened? What did you expect?',
                      alignLabelWithHint: true,
                    ),
                    forceErrorText: _fieldErrors['description'],
                    onChanged: (_) => _clearFieldError('description'),
                    validator: Validators.ticketDescription,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final cat in _categories)
                    SizedBox(
                      width: w,
                      child: _ChoiceCard(
                        icon: AppTheme.categoryIcon(cat.name),
                        color: AppTheme.categoryColor(cat.name),
                        label: cat.name,
                        selected: _categoryId == cat.id,
                        onTap: () => setState(() {
                          _categoryId = cat.id;
                          _categoryMissing = false;
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_categoryMissing || _fieldErrors['categoryId'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(_fieldErrors['categoryId'] ?? 'Choose a category',
                  style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ),
          const SizedBox(height: 22),
          Text('Priority', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in _priorities)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PriorityOption(
                      priority: p,
                      selected: _priorityId == p.id,
                      onTap: () => setState(() => _priorityId = p.id),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Photo (optional)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _photo == null
              ? _AddPhotoBox(onTap: _submitting ? null : _addPhoto)
              : _PhotoPreview(photo: _photo!, onRemove: _submitting ? null : () => setState(() => _photo = null)),
          const SizedBox(height: 26),
          if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 14)],
          GradientButton(label: 'Submit ticket', icon: Icons.send_rounded, loading: _submitting, onPressed: _submit),
        ],
      ),
    );
  }
}

/// KB-3: "These articles might help".
class _SuggestionBox extends StatelessWidget {
  const _SuggestionBox({required this.articles});

  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: AppColors.teal, size: 18),
              SizedBox(width: 6),
              Text('These articles might help',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 4),
          for (final a in articles)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArticleScreen(articleId: a.id))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.article_rounded, size: 16, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.title, style: const TextStyle(fontSize: 13.5, color: AppColors.ink))),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.icon, required this.color, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? color : Colors.transparent, width: 1.8),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconTile(icon: icon, color: color, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({required this.priority, required this.selected, required this.onTap});

  final TicketPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.priority(priority.level);
    final hours = priority.resolutionHours;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: selected ? AppShadows.glow(color) : AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Icon(Icons.flag_rounded, color: selected ? Colors.white : color),
                const SizedBox(height: 4),
                Text(priority.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? Colors.white : AppColors.ink)),
                if (hours != null)
                  Text('$hours h',
                      style: TextStyle(fontSize: 11, color: selected ? Colors.white.withValues(alpha: 0.85) : AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoBox extends StatelessWidget {
  const _AddPhotoBox({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 30),
            SizedBox(height: 8),
            Text('Take a photo or choose one', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
            Text('JPG or PNG, up to 5 MB', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, required this.onRemove});

  final XFile photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(File(photo.path), height: 190, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton.filledTonal(tooltip: 'Remove photo', onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
        ),
      ],
    );
  }
}
