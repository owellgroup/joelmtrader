import 'package:flutter/material.dart';
import '../core/utils.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? context.cardColor2) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: context.isDark
            ? null
            : [BoxShadow(color: const Color(0xFF0000FF).withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: box);
  }
}

/// JPX Finance wordmark from assets/logo/logo.png.
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 88});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: TextStyle(fontSize: 12, color: context.muted))),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final String? hint;
  const KpiCard({super.key, required this.label, required this.value, required this.icon, this.valueColor, this.hint});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Palette.brand.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Palette.brand, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: context.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(value, key: ValueKey(value), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: valueColor)),
            ),
            if (hint != null) Text(hint!, style: TextStyle(fontSize: 10.5, color: context.muted)),
          ]),
        ),
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool pulse;
  const StatusPill(this.text, this.color, {super.key, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        pulse ? _Dot(color) : Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .3)),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  const _Dot(this.color);
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(c),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyState({super.key, required this.icon, required this.title, this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: context.muted.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(message!, textAlign: TextAlign.center, style: TextStyle(color: context.muted))),
          ]),
        ),
      );
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBanner(this.message, {super.key, this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Palette.red.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.red.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Palette.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

/// Lays children in 1..n columns depending on available width.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  const ResponsiveGrid({super.key, required this.children, this.minTileWidth = 240, this.spacing = 12});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minTileWidth).floor().clamp(1, 6);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(spacing: spacing, runSpacing: spacing, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String confirm = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Palette.red) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}
