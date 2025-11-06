import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';

typedef CustomActionHandler = void Function(
  BuildContext context,
  Map<String, dynamic>? parameters,
);

class ActionRegistry {
  static final ActionRegistry _instance = ActionRegistry._internal();

  factory ActionRegistry() => _instance;

  static ActionRegistry get instance => _instance;

  ActionRegistry._internal();

  final Map<String, CustomActionHandler> _customHandlers = {};

  void registerCustomHandler(String actionId, CustomActionHandler handler) {
    _customHandlers[actionId] = handler;
  }

  void registerMultipleHandlers(Map<String, CustomActionHandler> handlers) {
    _customHandlers.addAll(handlers);
  }

  void unregisterCustomHandler(String actionId) {
    _customHandlers.remove(actionId);
  }

  bool hasCustomHandler(String actionId) {
    return _customHandlers.containsKey(actionId);
  }

  List<String> getRegisteredHandlers() {
    return _customHandlers.keys.toList();
  }

  void clearCustomHandlers() {
    _customHandlers.clear();
  }

  void handleInteraction(BuildContext context, UserInteraction? interaction) {
    if (interaction == null || !interaction.isValid) {
      // No action or invalid action - silently ignore
      return;
    }

    switch (interaction.interactionType) {
      case UserInteractionType.internal:
        _handleInternalNavigation(context, interaction);
        break;

      case UserInteractionType.external:
        _handleExternalUrl(context, interaction);
        break;

      case UserInteractionType.custom:
        _handleCustomAction(context, interaction);
        break;

      case UserInteractionType.none:
        // Do nothing - intentional no-op
        break;
    }
  }

  void _handleInternalNavigation(BuildContext context, UserInteraction interaction) {
    if (interaction.route == null || interaction.route!.isEmpty) {
      return;
    }

    Navigator.pushNamed(
      context,
      interaction.route!,
      arguments: interaction.parameters,
    );
  }

  void _handleExternalUrl(BuildContext context, UserInteraction interaction) {
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

  void _handleCustomAction(BuildContext context, UserInteraction interaction) {
    final actionId = interaction.customActionId;

    if (actionId == null || actionId.isEmpty) {
      _showError(context, 'Invalid custom action: missing action ID');
      return;
    }

    final handler = _customHandlers[actionId];

    if (handler == null) {
      _showError(context, 'No handler registered for action: $actionId');
      return;
    }

    try {
      handler(context, interaction.parameters);
    } catch (e) {
      _showError(context, 'Error executing custom action "$actionId": $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}