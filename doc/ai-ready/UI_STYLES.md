# UI Styles — package:moose_core/ui.dart

## Overview

`package:moose_core/ui.dart` provides **hook-calling style facades** — thin static classes that delegate to the active palette plugin via `HookRegistry`. Plugins that need text, button, or input styles import this barrel; they never import from another plugin or from any app-level file.

```dart
import 'package:moose_core/ui.dart';
```

This single import exposes four classes:

| Class | Hook | Return type |
|---|---|---|
| `AppTextStyles` | `styles:text` | `TextStyle` |
| `AppButtonStyles` | `styles:button` | `ButtonStyle` |
| `AppInputStyles` | `styles:input` | `InputDecoration` |
| `AppCustomStyles` | `styles:custom` | `T` (generic) |

---

## Why facades, not concrete styles

The naive approach — importing a shared `app_text_styles.dart` from `lib/src/styles/` — has two problems:

1. **Not swappable.** If you ship a white-label product, you cannot change the fonts or colours without editing the shared file.
2. **Cross-plugin coupling.** Plugins that import each other's source directories create implicit dependencies that break isolation.

The facade approach separates the *contract* (method signatures in `moose_core`) from the *implementation* (concrete styles in a palette plugin). Any plugin can override the entire palette by registering a higher-priority handler on the relevant hook.

---

## Import

```dart
// Preferred — explicit, minimal
import 'package:moose_core/ui.dart';

// Also available via the full barrel (if already imported)
import 'package:moose_core/moose_core.dart'; // does NOT re-export ui.dart — use explicit import
```

`ui.dart` is intentionally kept as a separate barrel from `moose_core.dart` to avoid pulling UI dependencies into non-widget code (repositories, adapters, pure data classes).

---

## AppTextStyles

### Methods

All methods take a `BuildContext` and return a `TextStyle` resolved through the `styles:text` hook.

| Method | Typical use |
|---|---|
| `appBarTitle(context)` | AppBar titles — uppercase, tight letter-spacing |
| `sectionHeader(context)` | Subsection headings inside a screen |
| `formLabel(context)` | `InputDecoration.labelStyle` across forms |
| `screenTitle(context)` | Large page headings (auth screens, onboarding) |
| `modalTitle(context)` | Bottom-sheet and dialog titles |
| `bodySecondary(context)` | De-emphasised body copy (descriptions, metadata) |
| `hint(context)` | Placeholder / hint text in inputs |
| `caption(context)` | Badges, chips, small labels |
| `sectionLabel(context)` | Compact category labels, filter chip text |
| `bodyMedium(context)` | Standard body text — medium weight |
| `bodyLarge(context)` | Slightly larger body text |
| `bodyXLarge(context)` | Prominent body text (product prices, totals) |

### Usage

```dart
import 'package:moose_core/ui.dart';

// In a widget build():
Text(
  'ORDER SUMMARY',
  style: AppTextStyles.sectionHeader(context),
),

// With copyWith to adjust a single property:
Text(
  product.name,
  style: AppTextStyles.screenTitle(context).copyWith(letterSpacing: -0.5),
),

// As InputDecoration.labelStyle:
TextFormField(
  decoration: InputDecoration(
    labelText: 'Email',
    labelStyle: AppTextStyles.formLabel(context),
  ),
),
```

---

## AppButtonStyles

### Methods

| Method | Widget | Description |
|---|---|---|
| `primary(context)` | `ElevatedButton` | Full-width, theme primary colour |
| `primaryCompact(context)` | `ElevatedButton` | Auto-width, theme primary colour |
| `secondary(context)` | `OutlinedButton` | Full-width, outlined |
| `secondaryCompact(context)` | `OutlinedButton` | Auto-width, outlined |
| `labelStyle({...})` | Any | Button label `TextStyle` — no `BuildContext` needed |

`labelStyle` is a pure static that has no `BuildContext` parameter. Font family is inherited from the app's text theme (set by the palette plugin's `ThemeData`).

### Usage

```dart
import 'package:moose_core/ui.dart';

// Full-width primary CTA
ElevatedButton(
  style: AppButtonStyles.primary(context),
  onPressed: _submit,
  child: Text(
    'PLACE ORDER',
    style: AppButtonStyles.labelStyle(),
  ),
),

// Compact secondary — sits in a Row
OutlinedButton(
  style: AppButtonStyles.secondaryCompact(context),
  onPressed: _cancel,
  child: Text(
    'CANCEL',
    style: AppButtonStyles.labelStyle(color: Theme.of(context).colorScheme.onSurface),
  ),
),

// labelStyle customisation
AppButtonStyles.labelStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
)
```

---

## AppInputStyles

### Methods

| Method | Description |
|---|---|
| `outlined(context, {labelText, suffixIcon})` | Simple outlined border — used in auth screens |
| `filled(context, {hintText, prefixIcon})` | Filled with rounded corners — used in address / search forms |

### Usage

```dart
import 'package:moose_core/ui.dart';

// Outlined — auth form field
TextFormField(
  decoration: AppInputStyles.outlined(
    context,
    labelText: 'Password',
    suffixIcon: IconButton(
      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _obscure = !_obscure),
    ),
  ),
),

// Filled — address / search field
TextFormField(
  decoration: AppInputStyles.filled(
    context,
    hintText: 'Search address',
    prefixIcon: const Icon(Icons.search),
  ),
),
```

---

## AppCustomStyles

`AppCustomStyles.get<T>(context, name)` is the extension point for any style that does not belong in the three core facades. Any plugin can register named styles under the `styles:custom` hook; any other plugin can consume them without a direct import.

### Method

```dart
static T get<T>(BuildContext context, String name)
```

`T` can be `TextStyle`, `ButtonStyle`, `InputDecoration`, `BoxDecoration`, or any other type.

### Registering a custom style

```dart
// In FeaturePlugin.onRegister():
hookRegistry.register('styles:custom', (data) {
  final map = data as Map<String, dynamic>;
  final name = map['name'] as String;
  final context = map['context'] as BuildContext;

  switch (name) {
    case 'promo_badge':
      return TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.error,
      );
    case 'card_elevated':
      return BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    default:
      return map; // pass through — let lower-priority handlers resolve it
  }
}, priority: 10);
```

### Consuming a custom style

```dart
import 'package:moose_core/ui.dart';

// TextStyle
final badge = AppCustomStyles.get<TextStyle>(context, 'promo_badge');

// BoxDecoration
final card = AppCustomStyles.get<BoxDecoration>(context, 'card_elevated');
```

---

## Hook reference

### styles:text

**Data:** `Map<String, dynamic>` with keys `name` (String) and `context` (BuildContext).
**Returns:** `TextStyle`

```dart
hookRegistry.register('styles:text', (data) {
  final map = data as Map<String, dynamic>;
  final name = map['name'] as String;
  final ctx  = map['context'] as BuildContext;
  return MyTextStyles.resolve(name, ctx);
});
```

### styles:button

**Data:** `Map<String, dynamic>` with keys `name` (String) and `context` (BuildContext).
**Returns:** `ButtonStyle`

```dart
hookRegistry.register('styles:button', (data) {
  final map = data as Map<String, dynamic>;
  return MyButtonStyles.resolve(map['name'] as String, map['context'] as BuildContext);
});
```

### styles:input

**Data:** `Map<String, dynamic>` with keys `name` (String), `context` (BuildContext), plus optional `labelText` / `hintText` / `suffixIcon` / `prefixIcon`.
**Returns:** `InputDecoration`

```dart
hookRegistry.register('styles:input', (data) {
  final map = data as Map<String, dynamic>;
  return MyInputStyles.resolve(map['name'] as String, map['context'] as BuildContext, map);
});
```

### styles:custom

**Data:** `Map<String, dynamic>` with keys `name` (String) and `context` (BuildContext). Additional keys are allowed.
**Returns:** any type — cast by the caller via `AppCustomStyles.get<T>`.

---

## Building a palette plugin

A palette plugin registers all four hooks and is swapped out by removing it from the plugin list in `main.dart` and adding an alternative. No other code changes are needed.

```dart
class MyBrandPlugin extends FeaturePlugin {
  @override
  String get name => 'my_brand';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    hookRegistry.register('styles:text', (data) {
      final map = data as Map<String, dynamic>;
      return MyBrandTextStyles.resolve(
        map['name'] as String,
        map['context'] as BuildContext,
      );
    });

    hookRegistry.register('styles:button', (data) {
      final map = data as Map<String, dynamic>;
      return MyBrandButtonStyles.resolve(
        map['name'] as String,
        map['context'] as BuildContext,
      );
    });

    hookRegistry.register('styles:input', (data) {
      final map = data as Map<String, dynamic>;
      return MyBrandInputStyles.resolve(
        map['name'] as String,
        map['context'] as BuildContext,
        map,
      );
    });

    // Optional — theme hook for ThemeManagerPlugin
    hookRegistry.register('theme:palette_light', (_) => MyBrandThemes.light);
    hookRegistry.register('theme:palette_dark',  (_) => MyBrandThemes.dark);
  }
}
```

Structure of each concrete style class:

```dart
abstract final class MyBrandTextStyles {
  static TextStyle resolve(String name, BuildContext ctx) {
    switch (name) {
      case 'appBarTitle':   return appBarTitle(ctx);
      case 'sectionHeader': return sectionHeader(ctx);
      // ... all 12 names
      default: throw ArgumentError('Unknown text style: $name');
    }
  }

  static TextStyle appBarTitle(BuildContext ctx) => TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
    color: Theme.of(ctx).colorScheme.onSurface,
  );

  // ... remaining methods
}
```

### Partially overriding a palette

Register only the hooks you want to override at a higher priority. Hooks not registered fall through to the lower-priority default handler (e.g. `ThemeDefaultPlugin`):

```dart
// Override only the appBarTitle style; everything else stays default
hookRegistry.register('styles:text', (data) {
  final map = data as Map<String, dynamic>;
  if (map['name'] == 'appBarTitle') {
    return TextStyle(fontFamily: 'Playfair Display', fontSize: 14, ...);
  }
  return map; // pass through to default handler
}, priority: 10);
```

---

## ThemeDefaultPlugin — the built-in palette

`ThemeDefaultPlugin` (in `moose_extensions`) is the reference implementation. It registers:

| Hook | Handled by |
|---|---|
| `styles:text` | `DefaultTextStyles.resolve(name, ctx)` |
| `styles:button` | `DefaultButtonStyles.resolve(name, ctx)` |
| `styles:input` | `DefaultInputStyles.resolve(name, ctx, map)` |
| `theme:palette_light` | `DefaultThemes.light` |
| `theme:palette_dark` | `DefaultThemes.dark` |

The default palette uses **Inter** (via `google_fonts`) with colours sourced entirely from `ThemeData.colorScheme`. It has no hard-coded hex values, so light/dark mode works automatically.

---

## Rules for AI agents

1. **Always import `package:moose_core/ui.dart`** — never import from another plugin's `src/styles/` directory.

2. **Always call style methods inside `build()`** — they require a live `BuildContext` with `MooseScope` in the ancestor chain. Never call them inside `BlocProvider.create`, `initState`, or other lifecycle methods.

   ```dart
   // WRONG
   BlocProvider(
     create: (ctx) => MyBloc(style: AppTextStyles.bodyMedium(ctx)), // ctx has no MooseScope
   )

   // CORRECT
   final style = AppTextStyles.bodyMedium(context); // capture in build()
   return BlocProvider(
     create: (_) => MyBloc(style: style),
   );
   ```

3. **Use `copyWith` for minor adjustments** — don't re-implement a style from scratch. Adjust one or two properties and leave the rest to the palette:

   ```dart
   AppTextStyles.sectionHeader(context).copyWith(color: Colors.white)
   ```

4. **Register style hooks in `onRegister()`** — hooks must be registered synchronously, before `onInit()` runs.

5. **Pass through unknown names in `styles:custom`** — return `map` (the incoming data) for unrecognised names so lower-priority handlers get a chance to resolve them.

6. **`AppButtonStyles.labelStyle()` has no `BuildContext`** — do not try to read theme colours from it. Use `color:` parameter or wrap in a `DefaultTextStyle` at the widget level.

7. **Palette plugins are mutually exclusive by convention** — register only one plugin that handles `styles:text`, `styles:button`, and `styles:input`. Using two without explicit priority differences will cause the last-registered one to silently win.

---

## Related

- [REGISTRIES.md](./REGISTRIES.md) — HookRegistry API, priority system, hook naming conventions
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — Plugin lifecycle, `onRegister()`, where to put hook registrations
- [EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md) — HookRegistry patterns in depth
- [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) — Cross-plugin import anti-patterns
