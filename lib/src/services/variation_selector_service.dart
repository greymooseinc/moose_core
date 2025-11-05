import '../entities/product_attribute.dart';
import '../entities/product_variation.dart';

class VariationSelectorService {
  ProductVariation? findMatchingVariation({
    required List<ProductVariation> variations,
    required Map<String, String> selectedAttributes,
  }) {
    for (final variation in variations) {
      if (_attributesMatch(variation.attributes, selectedAttributes)) {
        return variation;
      }
    }
    return null;
  }

  bool _attributesMatch(
    Map<String, String> variationAttributes,
    Map<String, String> selectedAttributes,
  ) {
    if (variationAttributes.length != selectedAttributes.length) {
      return false;
    }

    for (final entry in selectedAttributes.entries) {
      final variationValue = variationAttributes[entry.key];
      if (variationValue == null ||
          variationValue.toLowerCase() != entry.value.toLowerCase()) {
        return false;
      }
    }

    return true;
  }

  List<String> getAvailableOptions({
    required List<ProductVariation> variations,
    required String id,
    required Map<String, String> currentSelections,
  }) {
    final availableOptions = <String>{};

    for (final variation in variations) {
      if (!variation.inStock) continue;

      final matchesOtherAttributes = currentSelections.entries
          .where((e) => e.key != id)
          .every((selection) {
        final varValue = variation.attributes[selection.key];
        return varValue != null &&
               varValue.toLowerCase() == selection.value.toLowerCase();
      });

      if (matchesOtherAttributes) {
        final optionValue = variation.attributes[id];
        if (optionValue != null) {
          availableOptions.add(optionValue);
        }
      }
    }

    return availableOptions.toList();
  }

  bool isOptionAvailable({
    required List<ProductVariation> variations,
    required String attributeId,
    required String optionValue,
    required Map<String, String> currentSelections,
  }) {
    final testSelections = Map<String, String>.from(currentSelections);
    testSelections[attributeId] = optionValue;

    return variations.any((variation) {
      if (!variation.inStock) return false;

      return testSelections.entries.every((selection) {
        final varValue = variation.attributes[selection.key];
        return varValue != null &&
               varValue.toLowerCase() == selection.value.toLowerCase();
      });
    });
  }

  Map<String, String> getDefaultSelections({
    required List<ProductAttribute> attributes,
    required List<ProductVariation> variations,
  }) {
    final selections = <String, String>{};

    final variationAttributes = attributes.where((a) => a.variation).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    for (final attribute in variationAttributes) {
      if (attribute.options.isEmpty) continue;

      for (final option in attribute.options) {
        if (isOptionAvailable(
          variations: variations,
          attributeId: attribute.id,
          optionValue: option,
          currentSelections: selections,
        )) {
          selections[attribute.id] = option;
          break;
        }
      }
    }

    return selections;
  }

  ProductVariation? getDefaultVariation({
    required List<ProductVariation> variations,
  }) {
    return variations.firstWhere(
      (v) => v.inStock,
      orElse: () => variations.isNotEmpty ? variations.first :
                    throw Exception('No variations available'),
    );
  }
}
