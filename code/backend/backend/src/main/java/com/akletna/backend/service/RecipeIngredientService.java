package com.akletna.backend.service;

import com.akletna.backend.dto.RecipeIngredientRequest;
import com.akletna.backend.dto.RecipeIngredientResponse;
import com.akletna.backend.entity.Ingredient;
import com.akletna.backend.entity.Recipe;
import com.akletna.backend.entity.RecipeIngredient;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.repository.RecipeIngredientRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@org.springframework.transaction.annotation.Transactional
public class RecipeIngredientService {

    private final RecipeIngredientRepository recipeIngredientRepository;
    private final RecipeService recipeService;
    private final IngredientService ingredientService;

    public RecipeIngredientService(RecipeIngredientRepository recipeIngredientRepository,
                                   RecipeService recipeService,
                                   IngredientService ingredientService) {
        this.recipeIngredientRepository = recipeIngredientRepository;
        this.recipeService = recipeService;
        this.ingredientService = ingredientService;
    }

    public RecipeIngredientResponse addIngredientToRecipe(Long recipeId, RecipeIngredientRequest request, String userEmail) {
        // Enforces recipe ownership
        Recipe recipe = recipeService.getLockedRecipeAndVerifyOwner(recipeId, userEmail);

        // Ensures ingredient exists
        Ingredient ingredient = ingredientService.getIngredientEntity(request.getIngredientId());

        // Prevents duplicate line items of the same ingredient in the same recipe
        if (recipeIngredientRepository.existsByRecipeIdAndIngredientId(recipeId, ingredient.getId())) {
            throw new BadRequestException("Ingredient '" + ingredient.getName() + "' is already in this recipe. Update its quantity instead.");
        }

        RecipeIngredient recipeIngredient = new RecipeIngredient();
        recipeIngredient.setRecipe(recipe);
        recipeIngredient.setIngredient(ingredient);
        recipeIngredient.setUnit(QuantityUnit.normalizeInput(ingredient.getUnit()));
        recipeIngredient.setQuantity(request.getQuantity());
        if (request.getUnit() != null) recipeIngredient.setUnit(QuantityUnit.normalizeInput(request.getUnit()));

        RecipeIngredient saved = recipeIngredientRepository.save(recipeIngredient);
        return mapToResponse(saved);
    }

    public List<RecipeIngredientResponse> getIngredientsForRecipe(Long recipeId, String userEmail) {
        recipeService.getRecipeEntityAndVerifyReadable(recipeId, userEmail);

        return recipeIngredientRepository.findByRecipeId(recipeId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public RecipeIngredientResponse updateRecipeIngredient(Long recipeId, Long recipeIngredientId,
                                                           RecipeIngredientRequest request, String userEmail) {
        // Enforces recipe ownership
        recipeService.getLockedRecipeAndVerifyOwner(recipeId, userEmail);

        RecipeIngredient recipeIngredient = recipeIngredientRepository.findByIdAndRecipeId(recipeIngredientId, recipeId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe ingredient item not found with id: " + recipeIngredientId));

        // If client requested changing the ingredient reference itself
        if (request.getIngredientId() != null && !request.getIngredientId().equals(recipeIngredient.getIngredient().getId())) {
            Ingredient newIngredient = ingredientService.getIngredientEntity(request.getIngredientId());

            if (recipeIngredientRepository.existsByRecipeIdAndIngredientId(recipeId, newIngredient.getId())) {
                throw new BadRequestException("Ingredient '" + newIngredient.getName() + "' is already assigned to this recipe.");
            }
            recipeIngredient.setIngredient(newIngredient);
            recipeIngredient.setUnit(QuantityUnit.normalizeInput(newIngredient.getUnit()));
        }

        recipeIngredient.setQuantity(request.getQuantity());
        if (request.getUnit() != null) recipeIngredient.setUnit(QuantityUnit.normalizeInput(request.getUnit()));

        RecipeIngredient updated = recipeIngredientRepository.save(recipeIngredient);
        return mapToResponse(updated);
    }

    public void removeIngredientFromRecipe(Long recipeId, Long recipeIngredientId, String userEmail) {
        // Enforces recipe ownership
        recipeService.getLockedRecipeAndVerifyOwner(recipeId, userEmail);

        RecipeIngredient recipeIngredient = recipeIngredientRepository.findByIdAndRecipeId(recipeIngredientId, recipeId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe ingredient item not found with id: " + recipeIngredientId));

        recipeIngredientRepository.delete(recipeIngredient);
    }

    private RecipeIngredientResponse mapToResponse(RecipeIngredient item) {
        return new RecipeIngredientResponse(
                item.getId(),
                item.getRecipe().getId(),
                item.getIngredient().getId(),
                item.getIngredient().getName(),
                item.getUnit(),
                item.getQuantity()
        );
    }
}
