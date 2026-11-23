import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../models/lookups.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/helpdesk_api.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';

/// Reads one help article (KB-2). Staff can edit it (KB-1).
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.articleId});

  final String articleId;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Article? _article;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await context.read<HelpdeskApi>().getArticle(widget.articleId);
      if (!mounted) return;
      setState(() {
        _article = a;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit(Article a) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ArticleEditorScreen(article: a)));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.select<AuthService, bool>((a) => a.isStaff);
    final a = _article;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeaderBar(
                  showBack: true,
                  title: 'Help article',
                  actions: [
                    if (isStaff && a != null)
                      HeaderIconButton(icon: Icons.edit_rounded, tooltip: 'Edit article', onPressed: () => _edit(a)),
                  ],
                ),
                if (a != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (a.categoryName != null)
                        Pill(label: a.categoryName!, color: AppTheme.categoryColor(a.categoryName), solid: true),
                      if (!a.published) const Pill(label: 'Draft', color: AppColors.warning, solid: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(a.title,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 6),
                  Text('${a.author?.name ?? 'Support team'} · ${a.readMinutes} min read · ${formatDate(a.updatedAt)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                ],
              ],
            ),
          ),
          Expanded(
            child: a == null
                ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const SkeletonList(count: 3, itemHeight: 140))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      FadeSlideIn(
                        child: AppCard(
                          padding: const EdgeInsets.all(22),
                          child: SelectableText(a.body, style: const TextStyle(fontSize: 15.5, height: 1.7, color: AppColors.ink)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const MessageBanner('Still need help? Raise a ticket with the + button and our team will reply.'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Create or edit an article (KB-1). Agents can publish; only an Admin can
/// unpublish a published article (KB-4).
class ArticleEditorScreen extends StatefulWidget {
  const ArticleEditorScreen({super.key, this.article});

  final Article? article;

  @override
  State<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends State<ArticleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.article?.title);
  late final _body = TextEditingController(text: widget.article?.body);
  late String? _categoryId = widget.article?.categoryId;
  late bool _published = widget.article?.published ?? false;
  List<TicketCategory> _categories = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<HelpdeskApi>().getCategories().then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<HelpdeskApi>().saveArticle(
            id: widget.article?.id,
            title: _title.text,
            body: _body.text,
            categoryId: _categoryId,
            published: _published,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((a) => a.user?.role == UserRole.admin);
    final lockedPublished = (widget.article?.published ?? false) && !isAdmin;
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            child: HeaderBar(
              showBack: true,
              title: widget.article == null ? 'New article' : 'Edit article',
              subtitle: 'Help Center',
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title_rounded)),
                          validator: (v) => (v?.trim().length ?? 0) < 5 ? 'Use at least 5 characters' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.label_rounded)),
                          items: [
                            for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _body,
                          minLines: 10,
                          maxLines: 20,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Article text', alignLabelWithHint: true),
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Write the article text' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Published', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(lockedPublished
                          ? 'Only an Admin can unpublish an article.'
                          : 'Published articles are visible to every user.'),
                      value: _published,
                      onChanged: lockedPublished ? null : (v) => setState(() => _published = v),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 14)],
                  GradientButton(label: 'Save article', icon: Icons.save_rounded, loading: _saving, onPressed: _save),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
