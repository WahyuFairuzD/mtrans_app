import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadNotice extends StatelessWidget {
  final bool loading;
  final bool loaded;
  final String? error;
  final VoidCallback onRetry;
  const LoadNotice({
    super.key,
    required this.loading,
    required this.loaded,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, color: Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (loading && !loaded) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}