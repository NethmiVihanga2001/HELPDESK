import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lookups.dart';
import '../models/ticket.dart';
import '../theme.dart';

// Shared building blocks of the HelpDesk Pro look: gradient headers, cards,
// chips, avatars, buttons and entrance animations.

/// Curved brand-gradient header with soft decorative circles. Sets light
/// status-bar icons while it is on screen.
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child, this.padding, this.radius = 32});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.vertical(bottom: Radius.circular(radius));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(gradient: AppColors.brand, borderRadius: shape),
        child: ClipRRect(
          borderRadius: shape,
          child: Stack(
            children: [
              const Positioned(top: -70, right: -50, child: _Bubble(size: 200, alpha: 0.10)),
              const Positioned(bottom: -60, left: -40, child: _Bubble(size: 150, alpha: 0.08)),
              SafeArea(
                bottom: false,
                child: Padding(padding: padding ?? const EdgeInsets.fromLTRB(20, 8, 20, 26), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

/// Top row inside a [GradientHeader]: optional back button, title, actions.
class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, this.title, this.subtitle, this.actions = const [], this.showBack = false});

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (showBack) ...[
            HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13)),
              ],
            ),
          ),
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
        ],
      ),
    );
  }
}

/// Round translucent icon button for gradient headers, with an optional
/// count badge.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.badge = 0});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              backgroundColor: AppColors.pink,
              offset: const Offset(6, -6),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width brand-gradient button with a loading state.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled || loading ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.brand,
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled ? AppShadows.glow(AppColors.primary) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                        Flexible(
                          child: Text(label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.5)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating brand-gradient pill button, e.g. "Add user".
class GradientFab extends StatelessWidget {
  const GradientFab({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.glow(AppColors.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section title with an optional action on the right ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Round avatar with initials on a colour picked from the name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, required this.initials, this.size = 40, this.ring = false});

  final String name;
  final String initials;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarPalette[name.hashCode.abs() % AppColors.avatarPalette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: ring ? Border.all(color: Colors.white, width: 3) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.36),
      ),
    );
  }
}

/// Icon in a tinted rounded square.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Small rounded label.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.icon, this.solid = false});

  final String label;
  final Color color;
  final IconData? icon;

  /// White pill with coloured text, for use on gradients.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? Colors.white : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.solid = false});

  final TicketStatus status;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.status(status);
    return Pill(label: status.label, color: style.color, icon: style.icon, solid: solid);
  }
}

class PriorityChip extends StatelessWidget {
  const PriorityChip(this.name, {super.key, this.solid = false});

  final String name;
  final bool solid;

  @override
  Widget build(BuildContext context) =>
      Pill(label: name, color: AppTheme.priority(PriorityLevel.fromName(name)), icon: Icons.flag_rounded, solid: solid);
}

class OverdueChip extends StatelessWidget {
  const OverdueChip({super.key, this.solid = false});

  final bool solid;

  @override
  Widget build(BuildContext context) =>
      Pill(label: 'Overdue', color: AppColors.danger, icon: Icons.alarm_rounded, solid: solid);
}

/// Rounded pill switch, e.g. "Assigned to me | Queue".
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.selected, required this.onChanged, this.onGradient = false});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onGradient ? Colors.white.withValues(alpha: 0.16) : AppColors.line.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == selected ? AppShadows.card : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: i == selected
                          ? AppColors.primary
                          : (onGradient ? Colors.white : AppColors.inkSoft),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// White rounded search box.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, this.onChanged, this.onClear});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.card),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search_rounded),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide.none,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a child in once, staggered by [index].
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index.clamp(0, 8) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// App mark: gradient rounded square with a headset icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 76, this.onGradient = false});

  final double size;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onGradient ? Colors.white : null,
        gradient: onGradient ? null : AppColors.brand,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: onGradient
          ? ShaderMask(
              shaderCallback: (r) => AppColors.brand.createShader(r),
              child: Icon(Icons.support_agent_rounded, size: size * 0.58, color: Colors.white),
            )
          : Icon(Icons.support_agent_rounded, size: size * 0.58, color: Colors.white),
    );
  }
}

enum BannerKind { info, success, warning, error }

/// Inline message box for form errors and notices.
class MessageBanner extends StatelessWidget {
  const MessageBanner(this.message, {super.key, this.kind = BannerKind.info});

  final String message;
  final BannerKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (kind) {
      BannerKind.info => (AppColors.primary, Icons.info_rounded),
      BannerKind.success => (AppColors.success, Icons.check_circle_rounded),
      BannerKind.warning => (AppColors.warning, Icons.hourglass_top_rounded),
      BannerKind.error => (AppColors.danger, Icons.error_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Color.lerp(color, AppColors.ink, 0.45), fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + value row used on detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.valueColor, this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          IconTile(icon: icon, color: AppColors.primary, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(value,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: valueColor ?? AppColors.ink)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Shows a short message at the bottom of the screen.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks a yes/no question. Returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
