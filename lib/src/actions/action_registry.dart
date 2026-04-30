import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';

import 'custom_action_dispatcher.dart';
import 'external_url_handler.dart';
import 'navigation_handler.dart';

export 'custom_action_dispatcher.dart' show CustomActionHandler;

class ActionRegistry {
  ActionRegistry({
    NavigationHandler? navigationHandler,
    ExternalUrlHandler? externalUrlHandler,
    CustomActionDispatcher? customActionDispatcher,
  })  : _navigationHandler = navigationHandler ?? const NavigationHandler(),
        _externalUrlHandler = externalUrlHandler ?? const ExternalUrlHandler(),
        _customActionDispatcher = customActionDispatcher ?? CustomActionDispatcher();

  final NavigationHandler _navigationHandler;
  final ExternalUrlHandler _externalUrlHandler;
  final CustomActionDispatcher _customActionDispatcher;

  // ---------------------------------------------------------------------------
  // Custom handler registration — delegate to CustomActionDispatcher
  // ---------------------------------------------------------------------------

  void registerCustomHandler(String actionId, CustomActionHandler handler) {
    _customActionDispatcher.registerHandler(actionId, handler);
  }

  void registerMultipleHandlers(Map<String, CustomActionHandler> handlers) {
    _customActionDispatcher.registerMultiple(handlers);
  }

  void unregisterCustomHandler(String actionId) {
    _customActionDispatcher.unregisterHandler(actionId);
  }

  bool hasCustomHandler(String actionId) {
    return _customActionDispatcher.hasHandler(actionId);
  }

  List<String> getRegisteredHandlers() {
    return _customActionDispatcher.registeredHandlers();
  }

  void clearCustomHandlers() {
    _customActionDispatcher.clearHandlers();
  }

  // ---------------------------------------------------------------------------
  // Interaction dispatch
  // ---------------------------------------------------------------------------

  void handleInteraction(BuildContext context, UserInteraction? interaction) {
    if (interaction == null || !interaction.isValid) {
      // No action or invalid action - silently ignore
      return;
    }

    switch (interaction.interactionType) {
      case UserInteractionType.internal:
        _navigationHandler.handle(context, interaction);
        break;

      case UserInteractionType.external:
        _externalUrlHandler.handle(context, interaction);
        break;

      case UserInteractionType.custom:
        _customActionDispatcher.handle(context, interaction);
        break;

      case UserInteractionType.none:
        // Do nothing - intentional no-op
        break;
    }
  }
}
