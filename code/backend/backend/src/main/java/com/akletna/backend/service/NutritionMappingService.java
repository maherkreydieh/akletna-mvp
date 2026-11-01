package com.akletna.backend.service;

import com.akletna.backend.entity.IngredientNutrition;
import com.akletna.backend.repository.*;
import com.akletna.backend.nutrition.UsdaFoodClient;
import com.akletna.backend.exception.ResourceNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NutritionMappingService {
    private final IngredientRepository ingredients;
    private final IngredientNutritionRepository profiles;
    private final UsdaFoodClient client;
    public NutritionMappingService(IngredientRepository ingredients, IngredientNutritionRepository profiles, UsdaFoodClient client) {
        this.ingredients = ingredients; this.profiles = profiles; this.client = client;
    }
    @Transactional
    public IngredientNutrition map(Long ingredientId, String foodId, String state) {
        var ingredient = ingredients.findById(ingredientId).orElseThrow(() -> new ResourceNotFoundException("Ingredient not found."));
        var profile = client.fetch(foodId); // Validate everything before modifying managed data.
        ingredient.setNutritionProvider(profile.food().provider()); ingredient.setExternalFoodId(profile.food().externalFoodId());
        ingredient.setPreparationState(state.trim());
        ingredients.save(ingredient);
        var stored = profiles.findById(ingredientId).orElse(null);
        if (stored == null) stored = new IngredientNutrition(ingredient, profile, state.trim());
        else stored.updateProfile(profile, state.trim());
        return profiles.save(stored);
    }
}
