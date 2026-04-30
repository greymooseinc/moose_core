// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/services.dart';

/// Handles internal navigation actions by delegating to [MooseNavigator].
class NavigationHandler {
  const NavigationHandler();

  void handle(BuildContext context, UserInteraction interaction) {
    if (interaction.route == null || interaction.route!.isEmpty) {
      return;
    }

    MooseNavigator.of(context).pushNamed(
      interaction.route!,
      arguments: interaction.parameters,
    );
  }
}
