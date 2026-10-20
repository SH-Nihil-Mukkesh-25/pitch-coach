import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

/// Predefined SVG icon asset names for the Pitch Coach design system.
class AppIcons {
  static const String mic = 'mic';
  static const String slides = 'slides';
  static const String fire = 'fire';
  static const String target = 'target';
  static const String diamond = 'diamond';
  static const String sun = 'sun';
  static const String sunrise = 'sunrise';
  static const String trophy = 'trophy';
  static const String bell = 'bell';
  static const String checkCircle = 'check_circle';
  static const String celebration = 'celebration';
  static const String sparkles = 'sparkles';
  static const String timer = 'timer';
  static const String chart = 'chart';
  static const String settings = 'settings';
  static const String person = 'person';
  static const String camera = 'camera';
  static const String crown = 'crown';
  static const String globe = 'globe';
  static const String moon = 'moon';
  static const String help = 'help';
  static const String chat = 'chat';
  static const String star = 'star';
  static const String info = 'info';
  static const String logout = 'logout';
  static const String trash = 'trash';
  static const String chevronRight = 'chevron_right';
  static const String book = 'book';
  static const String video = 'video';
  static const String clock = timer;
  static const String award = trophy;
  static const String search = target;

  // Map of canonical icon names to their asset paths
  static const Map<String, String> _paths = {
    mic: 'assets/icons/mic.svg',
    slides: 'assets/icons/slides.svg',
    fire: 'assets/icons/fire.svg',
    target: 'assets/icons/target.svg',
    diamond: 'assets/icons/diamond.svg',
    sun: 'assets/icons/sun.svg',
    sunrise: 'assets/icons/sunrise.svg',
    trophy: 'assets/icons/trophy.svg',
    bell: 'assets/icons/bell.svg',
    checkCircle: 'assets/icons/check_circle.svg',
    celebration: 'assets/icons/celebration.svg',
    sparkles: 'assets/icons/sparkles.svg',
    timer: 'assets/icons/timer.svg',
    chart: 'assets/icons/chart.svg',
    settings: 'assets/icons/settings.svg',
    person: 'assets/icons/person.svg',
    camera: 'assets/icons/camera.svg',
    crown: 'assets/icons/crown.svg',
    globe: 'assets/icons/globe.svg',
    moon: 'assets/icons/moon.svg',
    help: 'assets/icons/help.svg',
    chat: 'assets/icons/chat.svg',
    star: 'assets/icons/star.svg',
    info: 'assets/icons/info.svg',
    logout: 'assets/icons/logout.svg',
    trash: 'assets/icons/trash.svg',
    chevronRight: 'assets/icons/chevron_right.svg',
    book: 'assets/icons/book.svg',
    video: 'assets/icons/video.svg',
  };

  // Graceful resolution for legacy emoji database seeds and aliases
  static const Map<String, String> _aliases = {
    'first_session': mic,
    'microphone': mic,
    '7_day_streak': fire,
    'streak': fire,
    '50_sessions': target,
    'goal': target,
    'clarity_master': diamond,
    'gem': diamond,
    'clarity': diamond,
    'early_bird': sunrise,
    'sunrise': sunrise,
    'sun': sun,
    'light_mode': sun,
    'brightness': sun,
    'day': sun,
    'award': trophy,
    'achievement': trophy,
    'reminder': bell,
    'notification': bell,
    'check': checkCircle,
    'success': checkCircle,
    'party': celebration,
    'popper': celebration,
    'sparkle': sparkles,
    'ai': sparkles,
    'stopwatch': timer,
    'clock': timer,
    'analytics': chart,
  };

  /// Resolves an icon name or alias to its SVG asset path.
  static String resolveAssetPath(String name) {
    final direct = _paths[name];
    if (direct != null) return direct;

    final alias = _aliases[name];
    if (alias != null && _paths.containsKey(alias)) {
      return _paths[alias]!;
    }

    // Default fallback to trophy
    return _paths[trophy]!;
  }
}

/// Unified AppIcon widget that renders standard-stroke SVGs with dynamic tinting.
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ??
        IconTheme.of(context).color ??
        AppColors.textPrimaryOf(context);

    final path = AppIcons.resolveAssetPath(name);

    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}
