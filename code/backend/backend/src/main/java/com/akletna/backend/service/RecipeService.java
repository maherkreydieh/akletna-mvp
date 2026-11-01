package com.akletna.backend.service;

import com.akletna.backend.dto.RecipeRequest;
import com.akletna.backend.dto.RecipeResponse;
import com.akletna.backend.entity.Recipe;
import com.akletna.backend.entity.User;
import com.akletna.backend.entity.RecipeOrigin;
import com.akletna.backend.entity.RecipeVisibility;
import com.akletna.backend.entity.RecipeIngredient;
import com.akletna.backend.exception.BadRequestException;
import org.springframework.transaction.annotation.Transactional;
import java.util.HashSet;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.exception.UnauthorizedResourceException;
import com.akletna.backend.repository.RecipeRepository;
import com.akletna.backend.repository.MealPlanRepository;
import com.akletna.backend.repository.SavedRecipeRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class RecipeService {

    private final RecipeRepository recipeRepository;
    private final UserService userService;
    private final IngredientService ingredientService;
    private final MealPlanRepository mealPlanRepository;
    private final SavedRecipeRepository saves;
    private static final String REFERENCED_RECIPE_MESSAGE =
            "This recipe is used in a meal plan. Remove all planned meals referencing it before deleting it.";

    public RecipeService(RecipeRepository recipeRepository, UserService userService, IngredientService ingredientService,
                         MealPlanRepository mealPlanRepository, SavedRecipeRepository saves) {
        this.saves = saves;
        this.recipeRepository = recipeRepository;
        this.userService = userService;
        this.ingredientService = ingredientService;
        this.mealPlanRepository = mealPlanRepository;
    }

    @Transactional
    public RecipeResponse createRecipe(RecipeRequest request, String userEmail) {
        User user = userService.getUserByEmail(userEmail);

        Recipe recipe = new Recipe();
        recipe.setName(request.getName().trim());
        recipe.setDescription(request.getDescription());
        recipe.setInstructions(request.getInstructions());
        recipe.setServings(request.getServings());
        recipe.setCookingTime(request.getCookingTime());
        recipe.setCategory(request.getCategory());
        recipe.setImageUrl(request.getImageUrl());
        recipe.setCreatedAt(LocalDateTime.now());
        recipe.setUser(user);
        recipe.setOrigin(RecipeOrigin.USER);
        recipe.setVisibility(request.getVisibility() == null ? RecipeVisibility.PRIVATE : request.getVisibility());
        // Cascade existing RecipeIngredient relationships in the same transaction.
        if (request.getIngredients() != null) {
            recipe.getIngredients().addAll(buildIngredientLines(recipe, request));
        }

        Recipe saved = recipeRepository.save(recipe);
        return mapToResponse(saved);
    }

    public List<RecipeResponse> getAllUserRecipes(String userEmail) {
        User user = userService.getUserByEmail(userEmail);
        return mapCollection(getReadableRecipeEntities(user));
    }

    public List<Recipe> getReadableRecipeEntities(User user) {
        return recipeRepository.findByUserOrVisibilityOrderByCreatedAtDesc(user, RecipeVisibility.PUBLIC);
    }

    public List<RecipeResponse> getCuratedRecipes() {
        return mapCollection(recipeRepository.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.CURATED, RecipeVisibility.PUBLIC));
    }

    public List<RecipeResponse> getCommunityRecipes() {
        return mapCollection(recipeRepository.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.USER, RecipeVisibility.PUBLIC));
    }

    public RecipeResponse getRecipeById(Long id, String userEmail) {
        Recipe recipe = getRecipeEntityAndVerifyReadable(id, userEmail);
        RecipeResponse response = mapCollection(List.of(recipe)).getFirst();
        response.setSaved(saves.existsByUserIdAndRecipeId(userService.getUserByEmail(userEmail).getId(), id));
        return response;
    }

    public List<RecipeResponse> getMyRecipes(String userEmail) {
        User user = userService.getUserByEmail(userEmail);
        return mapCollection(recipeRepository.findByUserOrderByCreatedAtDesc(user).stream()
                .filter(recipe -> recipe.getOrigin() == RecipeOrigin.USER)
                .toList());
    }

    @Transactional
    public RecipeResponse updateRecipe(Long id, RecipeRequest request, String userEmail) {
        Recipe recipe = getLockedRecipeAndVerifyOwner(id, userEmail);
        // Resolve and validate every submitted line before changing managed data.
        List<RecipeIngredient> replacement = request.getIngredients() == null
                ? null : buildIngredientLines(recipe, request);
        if (request.getIngredients() != null) {
            recipe.getIngredients().clear();
            // Remove old rows before inserting replacements with the same unique ingredient key.
            recipeRepository.flush();
            recipe.getIngredients().addAll(replacement);
        }
        if (request.getVisibility() != null) {
            recipe.setVisibility(request.getVisibility());
            if (request.getVisibility() == RecipeVisibility.PRIVATE) saves.removeOtherUsers(id, recipe.getUser().getId());
        }

        recipe.setName(request.getName().trim());
        recipe.setDescription(request.getDescription());
        recipe.setInstructions(request.getInstructions());
        recipe.setServings(request.getServings());
        recipe.setCookingTime(request.getCookingTime());
        recipe.setCategory(request.getCategory());
        recipe.setImageUrl(request.getImageUrl());

        Recipe updated = recipeRepository.save(recipe);
        return mapToResponse(updated);
    }

    @Transactional
    public void deleteRecipe(Long id, String userEmail) {
        Recipe recipe = getLockedRecipeAndVerifyOwner(id, userEmail);
        if (mealPlanRepository.existsByRecipeId(id)) {
            throw new BadRequestException(REFERENCED_RECIPE_MESSAGE);
        }
        try {
            recipeRepository.delete(recipe);
            // The database FK also protects against a plan created after the check.
            recipeRepository.flush();
        } catch (DataIntegrityViolationException ex) {
            throw new BadRequestException(REFERENCED_RECIPE_MESSAGE);
        }
    }

    private List<RecipeIngredient> buildIngredientLines(Recipe recipe, RecipeRequest request) {
        var usedIngredients = new HashSet<Long>();
        var result = new java.util.ArrayList<RecipeIngredient>();
        for (var requested : request.getIngredients()) {
            if (!usedIngredients.add(requested.getIngredientId())) {
                throw new BadRequestException("Each ingredient may appear only once in a recipe.");
            }
            if (requested.getQuantity() == null || requested.getQuantity().signum() <= 0) {
                throw new BadRequestException("Ingredient quantity must be finite and positive.");
            }
            RecipeIngredient line = new RecipeIngredient();
            line.setRecipe(recipe);
            line.setIngredient(ingredientService.getIngredientEntity(requested.getIngredientId()));
            line.setQuantity(requested.getQuantity());
            // Old clients omit unit: preserve an existing recipe-line unit.
            String previousUnit = recipe.getIngredients().stream()
                    .filter(old -> old.getIngredient() != null && old.getIngredient().getId().equals(requested.getIngredientId()))
                    .map(old -> old.getUnit() == null ? "" : old.getUnit()).findFirst().orElse(null);
            line.setUnit(QuantityUnit.normalizeInput(requested.getUnit() != null ? requested.getUnit()
                    : previousUnit != null ? previousUnit : line.getIngredient().getUnit()));
            result.add(line);
        }
        return result;
    }

    public Recipe getRecipeEntityAndVerifyOwner(Long recipeId, String userEmail) {
        Recipe recipe = recipeRepository.findById(recipeId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found."));

        verifyReadable(recipe, userEmail);

        if (recipe.getOrigin() == RecipeOrigin.CURATED || !isOwner(recipe, userEmail)) {
            throw new UnauthorizedResourceException("You are not authorized to access or modify this recipe");
        }

        return recipe;
    }

    public Recipe getLockedRecipeAndVerifyOwner(Long id, String email) {
        Recipe recipe = recipeRepository.findLockedById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found."));
        verifyReadable(recipe, email);
        if (recipe.getOrigin() == RecipeOrigin.CURATED || !isOwner(recipe, email))
            throw new UnauthorizedResourceException("You are not authorized to access or modify this recipe");
        return recipe;
    }

    public List<RecipeResponse> mapCollection(List<Recipe> recipes) {
        var publicIds = recipes.stream().filter(r -> r.getVisibility() == RecipeVisibility.PUBLIC).map(Recipe::getId).toList();
        var counts = new java.util.HashMap<Long, Long>();
        if (!publicIds.isEmpty()) for (var count : saves.countsForRecipes(publicIds)) counts.put(count.getRecipeId(), count.getSaveCount());
        return recipes.stream().map(recipe -> {
            var response = mapToResponse(recipe);
            if (recipe.getVisibility() == RecipeVisibility.PUBLIC) response.setSaveCount(counts.getOrDefault(recipe.getId(), 0L));
            return response;
        }).toList();
    }

    public Recipe getRecipeEntityAndVerifyReadable(Long recipeId, String userEmail) {
        Recipe recipe = recipeRepository.findById(recipeId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found."));
        return verifyReadable(recipe,userEmail);
    }

    public Recipe getRecipeForGrocery(Long recipeId,String userEmail) {
        return verifyReadable(recipeRepository.findForGrocery(recipeId)
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found.")),userEmail);
    }

    private Recipe verifyReadable(Recipe recipe,String userEmail) {
        if (recipe.getVisibility() != RecipeVisibility.PUBLIC && !isOwner(recipe, userEmail)) {
            throw new ResourceNotFoundException("Recipe not found.");
        }
        return recipe;
    }

    private boolean isOwner(Recipe recipe, String email) {
        return recipe.getUser() != null && recipe.getUser().getEmail().equalsIgnoreCase(email);
    }

    private RecipeResponse mapToResponse(Recipe recipe) {
        RecipeResponse response = new RecipeResponse(
                recipe.getId(),
                recipe.getName(),
                recipe.getDescription(),
                recipe.getInstructions(),
                recipe.getServings(),
                recipe.getCookingTime(),
                recipe.getCategory(),
                recipe.getImageUrl(),
                recipe.getCreatedAt(),
                recipe.getUser() != null ? recipe.getUser().getId() : null,
                recipe.getUser() != null ? recipe.getUser().getName() : null
        );
        response.setOrigin(recipe.getOrigin());
        response.setVisibility(recipe.getVisibility());
        return response;
    }
}
