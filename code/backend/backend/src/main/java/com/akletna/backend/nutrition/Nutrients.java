package com.akletna.backend.nutrition;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Values are kcal and grams. Provider records describe 100 g of edible food. */
public record Nutrients(BigDecimal caloriesKcal, BigDecimal proteinGrams,
                        BigDecimal carbohydratesGrams, BigDecimal fatGrams) {
    public Nutrients {
        for (var value : new BigDecimal[]{caloriesKcal, proteinGrams, carbohydratesGrams, fatGrams}) {
            if (value == null || value.signum() < 0) throw new IllegalArgumentException("Nutrients must be known and nonnegative.");
        }
    }

    public Nutrients multiply(BigDecimal factor) {
        return new Nutrients(caloriesKcal.multiply(factor), proteinGrams.multiply(factor),
                carbohydratesGrams.multiply(factor), fatGrams.multiply(factor));
    }

    public Nutrients plus(Nutrients other) {
        return new Nutrients(caloriesKcal.add(other.caloriesKcal), proteinGrams.add(other.proteinGrams),
                carbohydratesGrams.add(other.carbohydratesGrams), fatGrams.add(other.fatGrams));
    }

    public Nutrients perServing(int servings) {
        var divisor = BigDecimal.valueOf(servings);
        return new Nutrients(caloriesKcal.divide(divisor, 6, RoundingMode.HALF_UP),
                proteinGrams.divide(divisor, 6, RoundingMode.HALF_UP),
                carbohydratesGrams.divide(divisor, 6, RoundingMode.HALF_UP), fatGrams.divide(divisor, 6, RoundingMode.HALF_UP));
    }
}
