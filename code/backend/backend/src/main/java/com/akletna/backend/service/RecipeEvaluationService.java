package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.dto.RecipeEvaluationResponse.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.nutrition.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.util.*;
import static com.akletna.backend.entity.CompatibilityStatus.*;

/** Independent signals. No name inference, no network, no writes, no pantry score weighting. */
@Service
public class RecipeEvaluationService {
    private final UserPreferenceService preferences;
    private final IngredientClassificationRepository ingredientMetadata;
    private final RecipeClassificationRepository recipeMetadata;
    private final IngredientNutritionRepository nutrition;
    private final BigDecimal proteinThreshold;
    public RecipeEvaluationService(UserPreferenceService preferences,IngredientClassificationRepository ingredientMetadata,
            RecipeClassificationRepository recipeMetadata,IngredientNutritionRepository nutrition,
            @Value("${akletna.discovery.high-protein-min-grams-per-serving:20}") BigDecimal proteinThreshold) {
        if(proteinThreshold==null || proteinThreshold.signum()<=0) throw new IllegalArgumentException("High Protein threshold must be positive.");
        this.preferences=preferences;this.ingredientMetadata=ingredientMetadata;this.recipeMetadata=recipeMetadata;this.nutrition=nutrition;this.proteinThreshold=proteinThreshold;
    }
    @Transactional(readOnly=true)
    public Map<Long,RecipeEvaluationResponse> evaluate(User user,List<Recipe> recipes) {
        if(recipes.isEmpty()) return Map.of();
        var pref=preferences.forUser(user);
        return evaluate(pref, recipes);
    }
    /** Reuse an already-loaded private profile for multi-signal requests. */
    public Map<Long,RecipeEvaluationResponse> evaluate(PreferencesResponse pref,List<Recipe> recipes) {
        if(recipes.isEmpty()) return Map.of();
        var ids=new TreeSet<Long>();var foods=new TreeSet<String>();
        for(var recipe:recipes) for(var line:recipe.getIngredients()) if(line.getIngredient()!=null) {
            ids.add(line.getIngredient().getId());
            if(UsdaFoodClient.PROVIDER.equals(line.getIngredient().getNutritionProvider()) && line.getIngredient().getExternalFoodId()!=null)
                foods.add(line.getIngredient().getExternalFoodId());
        }
        var classifications=new HashMap<Long,IngredientClassification>();
        if(!ids.isEmpty()) ingredientMetadata.findForIngredients(ids).forEach(c->classifications.put(c.getIngredientId(),c));
        var budgets=new HashMap<Long,RecipeClassification>();
        recipeMetadata.findAllById(recipes.stream().map(Recipe::getId).toList()).forEach(c->budgets.put(c.getRecipeId(),c));
        var snapshots=new HashMap<FoodIdentity,Nutrients>();
        if(!foods.isEmpty()) for(var snapshot:nutrition.findSnapshots(UsdaFoodClient.PROVIDER,foods)) {
            try {
                snapshots.putIfAbsent(new FoodIdentity(snapshot.getProvider(),snapshot.getExternalFoodId(),snapshot.getPreparationState()),
                        new Nutrients(snapshot.getCaloriesKcal(),snapshot.getProteinGrams(),snapshot.getCarbohydratesGrams(),snapshot.getFatGrams()));
            } catch(IllegalArgumentException ex) { /* Unusable stored values cannot classify High Protein. */ }
        }
        var result=new LinkedHashMap<Long,RecipeEvaluationResponse>();
        for(var recipe:recipes) result.put(recipe.getId(),evaluate(recipe,pref,classifications,budgets.get(recipe.getId()),identity->Optional.ofNullable(snapshots.get(identity))));
        return result;
    }
    private RecipeEvaluationResponse evaluate(Recipe recipe,PreferencesResponse pref,
            Map<Long,IngredientClassification> metadata,RecipeClassification budget,NutritionProvider provider) {
        var reasons=new ArrayList<Reason>();var diets=new EnumMap<DietaryPreference,CompatibilityStatus>(DietaryPreference.class);
        boolean missingRequirements=recipe.getIngredients().isEmpty() || recipe.getIngredients().stream().anyMatch(l->l.getIngredient()==null);
        for(var diet:DietaryPreference.values()) {
            CompatibilityStatus state=missingRequirements ? UNKNOWN : COMPATIBLE;
            for(var line:recipe.getIngredients()) {
                var classification=line.getIngredient()==null ? null : metadata.get(line.getIngredient().getId());
                var lineState=classification==null ? UNKNOWN : diet==DietaryPreference.VEGAN ? classification.getVegan() : classification.getVegetarian();
                if(lineState==CONFLICT) state=CONFLICT;else if(lineState==UNKNOWN && state!=CONFLICT) state=UNKNOWN;
            }
            diets.put(diet,state);
            if(pref.getDietaryRestrictions().contains(diet.name()) && state!=COMPATIBLE)
                reasons.add(new Reason(state==CONFLICT?"DIETARY_CONFLICT":"DIETARY_UNKNOWN",state==CONFLICT?Severity.AVOID:Severity.UNCERTAIN,
                        state==CONFLICT?"Not compatible with "+diet.label()+" preference":"Dietary information incomplete for "+diet.label(),null));
        }
        boolean allergenIncomplete=missingRequirements;
        for(var line:recipe.getIngredients()) {
            if(line.getIngredient()==null) continue;
            var ingredient=line.getIngredient();var classification=metadata.get(ingredient.getId());
            if(classification==null || !classification.isAllergensComplete()) allergenIncomplete=true;
            if(classification!=null) for(var allergen:new TreeSet<>(classification.getAllergens()))
                if(pref.getAllergies().contains(allergen.name())) reasons.add(new Reason("ALLERGEN_CONFLICT",Severity.AVOID,"Contains "+allergen.label(),ingredient.getId()));
            if(pref.getDislikedIngredientIds().contains(ingredient.getId()))
                reasons.add(new Reason("DISLIKED_INGREDIENT",Severity.DISLIKE,"Contains a food you dislike: "+ingredient.getName(),ingredient.getId()));
        }
        if(allergenIncomplete && !pref.getAllergies().isEmpty()) reasons.add(new Reason("ALLERGEN_UNKNOWN",Severity.UNCERTAIN,"Allergen information incomplete",null));
        if(!pref.getLegacyAllergies().isEmpty() || !pref.getLegacyDietaryRestrictions().isEmpty())
            reasons.add(new Reason("LEGACY_RESTRICTION_UNKNOWN",Severity.UNCERTAIN,"Some older dietary settings need review before compatibility can be determined",null));
        if(!pref.getDislikedIngredients().isEmpty())
            reasons.add(new Reason("LEGACY_DISLIKE_UNRESOLVED",Severity.DISLIKE,"Older disliked foods need to be selected by ingredient; names are not used for matching",null));
        if(missingRequirements) reasons.add(new Reason("NO_INGREDIENT_INFORMATION",Severity.UNCERTAIN,"Ingredient information incomplete",null));
        CompatibilityStatus compatibility=reasons.stream().anyMatch(r->r.severity()==Severity.AVOID)?CONFLICT
                : reasons.stream().anyMatch(r->r.severity()==Severity.UNCERTAIN)?UNKNOWN:COMPATIBLE;
        var goals=new EnumMap<MealGoal,GoalStatus>(MealGoal.class);
        goals.put(MealGoal.BUDGET_FRIENDLY,recipe.getOrigin()==RecipeOrigin.CURATED && budget!=null
                ? budget.isBudgetFriendly()?GoalStatus.QUALIFIES:GoalStatus.DOES_NOT_QUALIFY:GoalStatus.UNKNOWN);
        var nutrients=missingRequirements ? new RecipeNutritionResponse(RecipeNutritionResponse.Status.UNAVAILABLE,null,null,List.of())
                : RecipeNutritionService.calculate(recipe,recipe.getIngredients(),provider);
        var protein=nutrients.status()==RecipeNutritionResponse.Status.COMPLETE ? nutrients.perServing().proteinGrams():null;
        goals.put(MealGoal.HIGH_PROTEIN,protein==null?GoalStatus.UNKNOWN:protein.compareTo(proteinThreshold)>=0?GoalStatus.QUALIFIES:GoalStatus.DOES_NOT_QUALIFY);
        return new RecipeEvaluationResponse(compatibility,List.copyOf(reasons),diets,goals,protein,proteinThreshold);
    }
}
