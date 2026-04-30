import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';

typedef CustomActionHandler = void Function(
  BuildContext context,
  Map<String, dynamic>? parameters,
);

/// Dispatches custom actions to registered [CustomActionHandler] callbacks.
class CustomActionDispatcher {
  CustomActionDispatcher();

  final Map<String, CustomActionHandler> _customHandlers = {};

  void registerHandler(String actionId, CustomActionHandler handler) {
    _customHandlers[actionId] = handler;
  }

  void registerMultiple(Map<String, CustomActionHandler> handlers) {
    _customHandlers.addAll(handlers);
  }

  void unregisterHandler(String actionId) {
    _customHandlers.remove(actionId);
  }

  bool hasHandler(String actionId) {
    return _customHandlers.containsKey(actionId);
  }

  List<String> registeredHandlers() {
    return _customHandlers.keys.toList();
  }

  void clearHandlers() {
    _customHandlers.clear();
  }

  void handle(BuildContext context, UserInteraction interaction) {
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
