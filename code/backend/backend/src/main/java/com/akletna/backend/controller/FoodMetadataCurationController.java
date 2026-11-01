package com.akletna.backend.controller;

import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.CuratorAccess;
import com.akletna.backend.exception.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.Set;

@RestController @RequestMapping("/api/food-metadata/curation")
public class FoodMetadataCurationController {
    private final IngredientRepository ingredients;
    private final RecipeRepository recipes;
    private final IngredientClassificationRepository ingredientMetadata;
    private final RecipeClassificationRepository recipeMetadata;
    private final String curatorToken;
    public FoodMetadataCurationController(IngredientRepository ingredients,RecipeRepository recipes,
            IngredientClassificationRepository ingredientMetadata,RecipeClassificationRepository recipeMetadata,
            @Value("${akletna.nutrition.curator-token:}") String curatorToken) {
        this.ingredients=ingredients;this.recipes=recipes;this.ingredientMetadata=ingredientMetadata;this.recipeMetadata=recipeMetadata;this.curatorToken=curatorToken;
    }
    public record IngredientReview(@NotNull Set<@NotNull Allergen> allergens,@NotNull Boolean allergensComplete,
            @NotNull CompatibilityStatus vegetarian,@NotNull CompatibilityStatus vegan,@AssertTrue boolean reviewed) {}
    public record RecipeReview(@NotNull Boolean budgetFriendly,@AssertTrue boolean reviewed) {}
    public record ReviewResponse(Long id,Instant reviewedAt) {}
    @PutMapping("/ingredients/{id}") @Transactional
    public ReviewResponse ingredient(@PathVariable Long id,@Valid @RequestBody IngredientReview request,
            @RequestHeader(value="X-Nutrition-Curator-Token",required=false) String supplied) {
        CuratorAccess.require(curatorToken,supplied);
        if(request.vegan()==CompatibilityStatus.COMPATIBLE && request.vegetarian()==CompatibilityStatus.CONFLICT)
            throw new BadRequestException("Vegan and vegetarian classifications contradict each other.");
        var ingredient=ingredients.findById(id).orElseThrow(()->new ResourceNotFoundException("Ingredient not found."));
        var metadata=ingredientMetadata.findById(id).orElseGet(IngredientClassification::new);
        metadata.setIngredient(ingredient);metadata.setAllergens(request.allergens());metadata.setAllergensComplete(request.allergensComplete());
        metadata.setVegetarian(request.vegan()==CompatibilityStatus.COMPATIBLE ? CompatibilityStatus.COMPATIBLE : request.vegetarian());
        metadata.setVegan(request.vegetarian()==CompatibilityStatus.CONFLICT ? CompatibilityStatus.CONFLICT : request.vegan());
        metadata.setReviewedAt(Instant.now());ingredientMetadata.save(metadata);
        return new ReviewResponse(id,metadata.getReviewedAt());
    }
    @PutMapping("/recipes/{id}") @Transactional
    public ReviewResponse recipe(@PathVariable Long id,@Valid @RequestBody RecipeReview request,
            @RequestHeader(value="X-Nutrition-Curator-Token",required=false) String supplied) {
        CuratorAccess.require(curatorToken,supplied);
        var recipe=recipes.findById(id).orElseThrow(()->new ResourceNotFoundException("Recipe not found."));
        if(recipe.getOrigin()!=RecipeOrigin.CURATED) throw new BadRequestException("Trusted Budget Friendly classification is reserved for curated recipes.");
        var metadata=recipeMetadata.findById(id).orElseGet(RecipeClassification::new);
        metadata.setRecipe(recipe);metadata.setBudgetFriendly(request.budgetFriendly());metadata.setReviewedAt(Instant.now());
        recipeMetadata.save(metadata);return new ReviewResponse(id,metadata.getReviewedAt());
    }
}
