package com.akletna.backend.service;

import java.math.BigDecimal;
import java.util.Locale;

/** Conservative, ingredient-independent units. No density or measurement convention guesses. */
public record QuantityUnit(Dimension dimension, String symbol, String canonicalUnit, int factor) {
    public enum Dimension { MASS, VOLUME, OTHER }

    public static QuantityUnit of(String input) {
        String trimmed = input == null ? "" : input.trim();
        String key = trimmed.toLowerCase(Locale.ROOT);
        return switch (key) {
            case "g" -> new QuantityUnit(Dimension.MASS, "g", "g", 1);
            case "kg" -> new QuantityUnit(Dimension.MASS, "kg", "g", 1000);
            case "ml" -> new QuantityUnit(Dimension.VOLUME, "mL", "mL", 1);
            case "l" -> new QuantityUnit(Dimension.VOLUME, "L", "mL", 1000);
            case "cup", "tbsp", "tsp", "piece" -> new QuantityUnit(Dimension.OTHER, key, key, 1);
            // Preserve legitimate custom units; only identical units (case-insensitive,
            // matching the existing contract) can aggregate. No word/plural/fuzzy aliases.
            default -> new QuantityUnit(Dimension.OTHER, trimmed, key, 1);
        };
    }

    public static String normalizeInput(String input) { return input == null ? null : of(input).symbol(); }
    public record CompatibilityKey(Dimension dimension, String canonicalUnit) {}
    public CompatibilityKey compatibilityKey() { return new CompatibilityKey(dimension, canonicalUnit); }
    public boolean compatibleWith(QuantityUnit other) {
        return compatibilityKey().equals(other.compatibilityKey());
    }
    public BigDecimal canonicalQuantity(BigDecimal quantity) { return quantity.multiply(BigDecimal.valueOf(factor)); }
    public QuantityScaling.Quantity canonicalQuantity(QuantityScaling.Quantity quantity) { return quantity.multiply(factor); }

    public record Display(BigDecimal quantity, String unit) {}
    /** Receives a finalized stored quantity; presentation is exact, with no second rounding. */
    public Display display(BigDecimal quantity) {
        BigDecimal canonical = canonicalQuantity(quantity);
        if (dimension != Dimension.OTHER && canonical.compareTo(BigDecimal.valueOf(1000)) >= 0)
            return new Display(canonical.movePointLeft(3), dimension == Dimension.MASS ? "kg" : "L");
        return new Display(canonical, dimension == Dimension.OTHER ? symbol : canonicalUnit);
    }
}
