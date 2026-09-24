import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';

class ErrorStateWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({super.key, this.message, this.onRetry});

  static String _formatMessage(String raw) {
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('No address associated with hostname') ||
        raw.contains('ClientException') ||
        raw.contains('Connection failed')) {
      return 'Network connection error. Please check your internet connection and try again.';
    }
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.monitor_outlined,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              AppText.get('error_title'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _formatMessage(message ?? AppText.get('error_message')),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: Text(AppText.get('try_again'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
