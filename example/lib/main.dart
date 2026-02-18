import 'package:flutter/material.dart';
import 'package:moose_core/moose_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configuration
  ConfigManager().initialize({
    'plugins': {
      'demo': {
        'active': true,
        'settings': {
          'greeting': 'Welcome to moose_core!',
        },
      },
    },
  });

  // Initialize persistent cache (required before using PersistentCache)
  await CacheManager.initPersistentCache();

  // Register plugins
  await PluginRegistry().registerPlugin(() => DemoPlugin());

  runApp(const MooseCoreExampleApp());
}

/// A minimal example plugin demonstrating the [FeaturePlugin] pattern.
///
/// In a real app, plugins register repository implementations via a
/// [BackendAdapter] and each plugin lives in its own package.
class DemoPlugin extends FeaturePlugin {
  @override
  String get name => 'demo';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> getDefaultSettings() => {
        'greeting': 'Hello from moose_core!',
      };

  @override
  void onRegister() {
    // Register a widget that can be rendered anywhere by name
    widgetRegistry.register(
      'demo.greeting',
      (context, {data, onEvent}) => const GreetingSection(),
    );
  }

  @override
  Future<void> initialize() async {
    // Async setup: warm cache, connect to services, etc.
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
        '/demo': (context) => const DemoScreen(),
      };
}

/// Example [FeatureSection] — a configurable, reusable UI building block.
class GreetingSection extends FeatureSection {
  const GreetingSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {
        'title': 'moose_core',
        'subtitle': 'Plugin-based Flutter e-commerce architecture',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getSetting<String>('title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            getSetting<String>('subtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class MooseCoreExampleApp extends StatelessWidget {
  const MooseCoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'moose_core Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routes: PluginRegistry().getAllRoutes(),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('moose_core Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // Render the registered widget dynamically by name
          WidgetRegistry().build('demo.greeting', context),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Concepts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _conceptTile(
                  'FeaturePlugin',
                  'Self-contained feature module with its own registries',
                ),
                _conceptTile(
                  'FeatureSection',
                  'Configurable UI building block with JSON-driven settings',
                ),
                _conceptTile(
                  'WidgetRegistry',
                  'Dynamic widget composition — render widgets by name',
                ),
                _conceptTile(
                  'BackendAdapter',
                  'Backend-agnostic repository implementation (WooCommerce, Shopify…)',
                ),
                _conceptTile(
                  'EventBus',
                  'Async pub/sub for inter-plugin communication',
                ),
                _conceptTile(
                  'HookRegistry',
                  'Synchronous data transformation hooks',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _conceptTile(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
