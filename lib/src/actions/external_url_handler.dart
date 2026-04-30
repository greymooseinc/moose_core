import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';

/// Handles external URL actions by displaying a snackbar with the URL.
class ExternalUrlHandler {
  const ExternalUrlHandler();

  void handle(BuildContext context, UserInteraction interaction) {
    if (interaction.url == null || interaction.url!.isEmpty) {
      return;
    }

    // TODO: Replace with url_launcher in production
    // For now, show a snackbar with the URL
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External URL: ${interaction.url}'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}
