package com.akletna.backend.nutrition;

import org.springframework.stereotype.Component;
import java.util.Optional;

/** Day 15 has no configured nutrient source and makes no external calls. */
@Component
public class UnavailableNutritionProvider implements NutritionProvider {
    @Override public Optional<Nutrients> per100Grams(FoodIdentity identity) { return Optional.empty(); }
}
