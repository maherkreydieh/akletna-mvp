package com.akletna.backend.nutrition;

import java.util.Optional;

public interface NutritionProvider {
    Optional<Nutrients> per100Grams(FoodIdentity identity);
}
