package com.akletna.backend.nutrition;

import org.springframework.stereotype.Component;
import java.util.Optional;

/** Test provider for unavailable nutrition; makes no external calls. */
@Component
public class UnavailableNutritionProvider implements NutritionProvider {
    @Override public Optional<Nutrients> per100Grams(FoodIdentity identity) { return Optional.empty(); }
}
