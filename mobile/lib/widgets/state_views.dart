import 'package:flutter/material.dart';

import '../theme.dart';

/// Loading, empty and error states (feature 10.8: the app never shows a
/// blank or frozen screen).

/// Shimmering placeholder cards shown while a list loads.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 104, this.padding = const EdgeInsets.all(20)});

  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.count,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 - 0.5;
          return Container(
            height: widget.itemHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 2, 0),
                end: Alignment(t * 2, 0),
                colors: const [Color(0xFFEDECF7), Color(0xFFF8F8FD), Color(0xFFEDECF7)],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Big icon in layered tinted circles, used by empty and error states.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.06)),
      alignment: Alignment.center,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.10)),
        alignment: Alignment.center,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.3)!]),
            boxShadow: AppShadows.glow(color),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Illustration(icon: Icons.wifi_off_rounded, color: AppColors.danger),
            const SizedBox(height: 20),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state. It scrolls so it can sit inside a [RefreshIndicator].
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color = AppColors.primary,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Illustration(icon: icon, color: color),
                  const SizedBox(height: 20),
                  Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ],
                  if (action != null) ...[const SizedBox(height: 20), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
