import 'package:flutter/material.dart';
import 'package:healthtrack/services/connection_status_service.dart';

/// Utility class for showing centralized success/error messages
class MessageUtils {
  /// Show a centered success message popup
  static void showSuccessMessage(
    BuildContext context,
    String message, {
    String title = "Success",
    Duration duration = const Duration(seconds: 3),
  }) {
    // Check if the context is still valid
    if (!context.mounted) return;
    
    _showCustomDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      backgroundColor: Colors.green.shade50,
      titleColor: Colors.green.shade700,
      duration: duration,
    );
  }

  /// Show a centered error message popup
  static void showErrorMessage(
    BuildContext context,
    String message, {
    String title = "Error",
    Duration duration = const Duration(seconds: 4),
  }) {
    // Check if the context is still valid
    if (!context.mounted) return;
    
    _showCustomDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.error,
      iconColor: Colors.red,
      backgroundColor: Colors.red.shade50,
      titleColor: Colors.red.shade700,
      duration: duration,
    );
  }

  /// Show a user-friendly network / connection error message.
  /// Converts raw exceptions (SocketException, TimeoutException, etc.)
  /// into readable copy via [ConnectionStatusService.friendlyError].
  static void showNetworkError(
    BuildContext context,
    Object error, {
    String title = 'Connection Error',
  }) {
    showErrorMessage(
      context,
      ConnectionStatusService.friendlyError(error),
      title: title,
    );
  }

  /// Show a centered warning message popup
  static void showWarningMessage(
    BuildContext context,
    String message, {
    String title = "Warning",
    Duration duration = const Duration(seconds: 3),
  }) {
    // Check if the context is still valid
    if (!context.mounted) return;
    
    _showCustomDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.warning,
      iconColor: Colors.orange,
      backgroundColor: Colors.orange.shade50,
      titleColor: Colors.orange.shade700,
      duration: duration,
    );
  }

  /// Show a centered info message popup
  static void showInfoMessage(
    BuildContext context,
    String message, {
    String title = "Information",
    Duration duration = const Duration(seconds: 3),
  }) {
    // Check if the context is still valid
    if (!context.mounted) return;
    
    _showCustomDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.info,
      iconColor: Colors.blue,
      backgroundColor: Colors.blue.shade50,
      titleColor: Colors.blue.shade700,
      duration: duration,
    );
  }

  /// Internal method to show the custom dialog
  static void _showCustomDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color titleColor,
    Duration duration = const Duration(seconds: 3),
    bool autoClose = true,
  }) {
    // Double-check if the context is still valid before showing dialog
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        // Auto-close dialog after duration
        if (autoClose) {
          Future.delayed(duration, () {
            // Check if context is still valid before trying to pop
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 300,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 48,
                          color: iconColor,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Check if context is still valid before trying to pop
                      if (context.mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show a loading dialog
  static void showLoadingDialog(
    BuildContext context, {
    String message = "Loading...",
  }) {
    // Check if the context is still valid
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    // Check if the context is still valid and can pop
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = "Yes",
    String cancelText = "No",
    Color confirmColor = Colors.red,
  }) async {
    // Check if the context is still valid
    if (!context.mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Check if context is still valid before trying to pop
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop(false);
                          }
                        },
                        child: Text(
                          cancelText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Check if context is still valid before trying to pop
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        child: Text(
                          confirmText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }
}