import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soe design system for Flutter: dark glass panels, pink -> violet -> indigo
/// accent, Geist type. Source of truth: DESIGN-SYSTEM.md in the portfolios repo.
/// Tests cannot download Geist; they set this to false and use bundled Roboto.
bool useGoogleFonts = true;

class DS {
  // Page + text (dark is the default theme).
  static const paper = Color(0xFF05070A);
  static const raised = Color(0xFF0B0F14);
  static const ink = Color(0xFFE8EDEF);
  static const inkSoft = Color(0xFF94A2A9);
  static const inkFaint = Color(0xFF7D8B92); // >= 4.5:1 on paper

  // Brand accent.
  static const pink = Color(0xFFF472B6);
  static const pinkInk = Color(0xFFFBCFE8);
  static const violet = Color(0xFF8B5CF6);
  static const indigo = Color(0xFF6366F1);
  static const g1 = Color(0xFFEC4899);

  // Semantic.
  static const ok = Color(0xFF39C684);
  static const warn = Color(0xFFF4A825);
  static const danger = Color(0xFFD34545);

  static const brand = LinearGradient(
    colors: [g1, indigo],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// The dark glass panel used for maps and hero areas.
  static const panel = LinearGradient(
    colors: [Color(0xFF1A1A1C), Color(0xFF1D2140), Color(0xFF34408F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, .45, 1],
  );

  static Color glass([double a = .08]) => Colors.white.withValues(alpha: a);
  static Color glassBorder([double a = .14]) =>
      Colors.white.withValues(alpha: a);

  static ThemeData dark() => _theme(Brightness.dark);
  static ThemeData light() => _theme(Brightness.light);

  static ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? paper : const Color(0xFFF1F3F4);
    final fg = dark ? ink : const Color(0xFF14191C);
    final scheme = ColorScheme.fromSeed(seedColor: pink, brightness: b)
        .copyWith(
          primary: dark ? pink : const Color(0xFFA5287F),
          onPrimary: dark ? const Color(0xFF2A0A1C) : Colors.white,
          surface: dark ? raised : Colors.white,
          onSurface: fg,
        );
    final base = ThemeData(
      brightness: b,
      useMaterial3: true,
      colorScheme: scheme,
    );
    final text =
        (useGoogleFonts
                ? GoogleFonts.geistTextTheme(base.textTheme)
                : base.textTheme.apply(fontFamily: 'Roboto'))
            .apply(bodyColor: fg, displayColor: fg);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
          color: fg,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? g1
              : Colors.white.withValues(alpha: .25),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF14172B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF14172B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Mono label, like the portfolio's small uppercase captions.
TextStyle monoLabel(BuildContext context) => useGoogleFonts
    ? GoogleFonts.geistMono(fontSize: 11, letterSpacing: 1.4, color: DS.inkFaint)
    : const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 11,
        letterSpacing: 1.4,
        color: DS.inkFaint,
      );

/// Frosted card. [hue] tints it like the portfolio's skill cards.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double hue;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.hue = 318,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = HSLColor.fromAHSL(1, hue, .75, .6).toColor();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dark ? DS.glassBorder() : const Color(0x1A1E2850),
            ),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? [tint.withValues(alpha: .20), tint.withValues(alpha: .04)]
                  : [tint.withValues(alpha: .16), Colors.white],
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Pill button with the brand gradient and glow.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool danger;
  const GradientButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: danger
          ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFB91C1C)])
          : DS.brand,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: (danger ? DS.danger : DS.g1).withValues(alpha: .45),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -10,
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Big number + mono caption, used for hike metrics.
class Metric extends StatelessWidget {
  final String label, value;
  const Metric(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ShaderMask(
        shaderCallback: (r) =>
            const LinearGradient(colors: [DS.pink, Color(0xFFA5B4FC)])
                .createShader(r),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -.8,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(label.toUpperCase(), style: monoLabel(context)),
    ],
  );
}

/// Mobile first: on a wide screen (desktop browser) show the app in a phone-
/// sized column; on a phone it fills the screen.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  static const maxWidth = 430.0;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w <= maxWidth + 40) return child;
    return ColoredBox(
      color: const Color(0xFF020304),
      child: Center(
        child: Container(
          width: maxWidth,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: DS.glassBorder(.25), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(maxWidth, MediaQuery.sizeOf(context).height - 32),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
