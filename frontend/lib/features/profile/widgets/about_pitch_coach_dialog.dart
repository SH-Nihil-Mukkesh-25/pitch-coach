import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_atmosphere.dart';

class AboutPitchCoachDialog extends StatelessWidget {
  const AboutPitchCoachDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AboutPitchCoachDialog(),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassSurface(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(AppIcons.mic, size: 32, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pitch Coach',
              style: AppTextStyles.headingL.copyWith(
                fontSize: 22,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 4),

            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '1.0.0';
                final build = snapshot.data?.buildNumber ?? '1';
                return Text(
                  'Version $version (Build $build)',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            Text(
              'Your personal AI-powered speech rehearsal and communication coach. Built for developers, founders, and speakers to master delivery.',
              style: AppTextStyles.bodyM.copyWith(
                fontSize: 13,
                color: AppColors.textSecondaryOf(context),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _launchUrl('https://pitchcoach.app/terms'),
                  child: Text(
                    'Terms of Service',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryPurpleLight,
                    ),
                  ),
                ),
                Text(
                  '•',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
                TextButton(
                  onPressed: () => _launchUrl('https://pitchcoach.app/privacy'),
                  child: Text(
                    'Privacy Policy',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryPurpleLight,
                    ),
                  ),
                ),
              ],
            ),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showLicensePage(
                  context: context,
                  applicationName: 'Pitch Coach',
                  applicationLegalese:
                      '© 2026 Pitch Coach Inc. All rights reserved.',
                );
              },
              child: Text(
                'Open-Source Licenses',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 40),
                side: BorderSide(color: AppColors.borderOf(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
