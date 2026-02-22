import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Diagnostic widget shown in **debug mode only** when [WidgetRegistry] cannot
/// find a registered section by name.
///
/// In release mode [WidgetRegistry.build] returns [SizedBox.shrink] instead.
class UnknownSectionWidget extends StatelessWidget {
  /// The section name that was requested but not found.
  final String requestedName;

  /// All section names currently in the registry.
  final List<String> availableKeys;

  const UnknownSectionWidget({
    super.key,
    required this.requestedName,
    required this.availableKeys,
  });

  @override
  Widget build(BuildContext context) {
    // Should never appear in release builds.
    assert(kDebugMode, 'UnknownSectionWidget should only be shown in debug mode');

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⚠ Unknown section',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested: "$requestedName"',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Registered: ${availableKeys.isEmpty ? "(none)" : availableKeys.join(", ")}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
