import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/helpdesk_api.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import 'article_screen.dart';

/// Help Center tab (KB-2): everyone searches and reads published articles.
/// Agents and Admins also see drafts and can write articles (KB-1).
class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Article>? _articles;
  String? _error;
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<HelpdeskApi>().getArticles(search: _search.text);
      if (mounted) {
        setState(() {
          _articles = list;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.select<AuthService, bool>((a) => a.isStaff);
    final articles = _articles;
    final categories = {for (final a in articles ?? const <Article>[]) ?a.categoryName}.toList()..sort();
    final shown = articles?.where((a) => _category == null || a.categoryName == _category).toList();

    return Column(
      children: [
        GradientHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderBar(
                title: 'Help Center',
                subtitle: 'Answers to common questions',
                actions: [
                  if (isStaff)
                    HeaderIconButton(
                      icon: Icons.edit_note_rounded,
                      tooltip: 'New article',
                      onPressed: () => _open(const ArticleEditorScreen()),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SearchField(controller: _search, hint: 'Search articles', onChanged: _onSearch, onClear: _load),
            ],
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              children: [
                for (final c in <String?>[null, ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: c == null ? null : Icon(AppTheme.categoryIcon(c), size: 16, color: AppTheme.categoryColor(c)),
                      label: Text(c ?? 'All topics'),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: shown == null
              ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const SkeletonList(itemHeight: 110))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: shown.isEmpty
                      ? const EmptyView(
                          icon: Icons.menu_book_rounded,
                          title: 'No articles found',
                          message: 'Try other words, or raise a ticket and we will help.',
                          color: AppColors.teal,
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => FadeSlideIn(
                            index: i,
                            child: _ArticleCard(
                              article: shown[i],
                              showStatus: isStaff,
                              onTap: () => _open(ArticleScreen(articleId: shown[i].id)),
                            ),
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.showStatus, required this.onTap});

  final Article article;
  final bool showStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final color = AppTheme.categoryColor(a.categoryName);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: Icons.article_rounded, color: color, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3)),
                const SizedBox(height: 4),
                Text(a.body.replaceAll('\n', ' '),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (a.categoryName != null) Pill(label: a.categoryName!, color: color),
                    Text('${a.readMinutes} min read · ${formatDate(a.updatedAt)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    if (showStatus && !a.published) const Pill(label: 'Draft', color: AppColors.warning, icon: Icons.edit_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
