package com.akletna.backend.nutrition;

import com.akletna.backend.repository.IngredientNutritionRepository;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import java.util.Optional;

/** The Day 15 calculation boundary now reads persisted, trusted USDA snapshots; no network calls. */
@Primary @Component
public class StoredNutritionProvider implements NutritionProvider {
    private final IngredientNutritionRepository profiles;
    public StoredNutritionProvider(IngredientNutritionRepository profiles) { this.profiles = profiles; }
    public Optional<Nutrients> per100Grams(FoodIdentity identity) {
        if (!UsdaFoodClient.PROVIDER.equals(identity.provider())) return Optional.empty();
        return profiles.findFirstByProviderAndExternalFoodIdAndPreparationStateOrderByFetchedAtDesc(identity.provider(), identity.externalFoodId(), identity.preparationState())
                .flatMap(profile -> {
                    try { return Optional.of(profile.nutrients()); }
                    catch (IllegalArgumentException invalidStoredValues) { return Optional.empty(); }
                });
    }
}
