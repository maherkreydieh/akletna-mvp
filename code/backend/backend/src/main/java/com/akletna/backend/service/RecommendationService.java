package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.dto.RecommendationsResponse.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class RecommendationService {
    private final UserService users;
    private final RecipeService recipes;
    private final UserPreferenceService preferences;
    private final RecipeEvaluationService evaluation;
    private final PantryItemRepository pantry;
    private final PantryMatchingService matching;
    private final SavedRecipeRepository saves;
    private final RecommendationPolicy policy;
    public RecommendationService(UserService users,RecipeService recipes,UserPreferenceService preferences,
            RecipeEvaluationService evaluation,PantryItemRepository pantry,PantryMatchingService matching,
            SavedRecipeRepository saves,RecommendationPolicy policy) {
        this.users=users;this.recipes=recipes;this.preferences=preferences;this.evaluation=evaluation;
        this.pantry=pantry;this.matching=matching;this.saves=saves;this.policy=policy;
    }
    @Transactional(readOnly=true)
    public RecommendationsResponse recommend(String email,String category,Set<MealGoal> goals,DietaryPreference diet) {
        return select(email,category,goals,diet,false).selection();
    }
    @Transactional(readOnly=true)
    public HomeRecommendationsResponse recommendHome(String email,String category,Set<MealGoal> goals,DietaryPreference diet) {
        return select(email,category,goals,diet,true);
    }
    private HomeRecommendationsResponse select(String email,String category,Set<MealGoal> goals,DietaryPreference diet,boolean home) {
        var user=users.getUserByEmail(email);
        var candidates=recipes.getReadableRecipeEntities(user).stream()
                .filter(r->r.getOrigin()==RecipeOrigin.USER || r.getVisibility()==RecipeVisibility.PUBLIC).toList();
        // Deduplicate by identity, never by ingredient/recipe names.
        var unique=new LinkedHashMap<Long,Recipe>();
        candidates.forEach(r->unique.putIfAbsent(r.getId(),r));
        candidates=List.copyOf(unique.values());
        var profile=preferences.forUser(user);
        var inventory=pantry.findForUser(user.getId());
        var evaluations=evaluation.evaluate(profile,candidates);
        var matches=matching.matchRecipes(candidates,inventory,evaluations);
        var byId=new HashMap<Long,PantryMatchesResponse.RecipeMatch>();
        matches.matches().forEach(m->byId.put(m.id(),m));
        var validIds=new HashSet<Long>();
        candidates.stream().filter(matching::valid).forEach(r->validIds.add(r.getId()));
        var saved=candidates.isEmpty()?Set.<Long>of():new HashSet<>(saves.savedIdsForUser(user.getId(),candidates.stream().map(Recipe::getId).toList()));
        var results=new ArrayList<Result>();
        int excluded=matches.excludedRecipeCount();
        for(var recipe:recipes.mapCollection(candidates)) {
            if(!validIds.contains(recipe.getId())) continue;
            var evaluated=evaluations.get(recipe.getId());
            if(home ? !policy.homeEligible(evaluated,profile) : !policy.eligible(evaluated)) {excluded++;continue;}
            if(category!=null && !category.isBlank() && !category.trim().equalsIgnoreCase(recipe.getCategory())) continue;
            if(goals!=null && goals.stream().anyMatch(g->evaluated.mealGoals().get(g)!=RecipeEvaluationResponse.GoalStatus.QUALIFIES)) continue;
            if(diet!=null && evaluated.diets().get(diet)!=CompatibilityStatus.COMPATIBLE) continue;
            recipe.setEvaluation(evaluated);recipe.setSaved(saved.contains(recipe.getId()));
            var match=byId.get(recipe.getId());
            var scored=home ? policy.homeScore(recipe,evaluated,profile) : policy.score(recipe,evaluated,profile,match);
            results.add(new Result(0,recipe,scored.score(),match==null?null:match.status(),match==null?null:match.score(),scored.reasons()));
        }
        if(home) results.sort(Comparator.comparing(Result::score,Comparator.reverseOrder()).thenComparing(r->r.recipe().getName().toLowerCase(Locale.ROOT)).thenComparing(r->r.recipe().getId()));
        else results.sort(Comparator.comparing(Result::score,Comparator.reverseOrder())
                .thenComparing(r->r.pantryStatus()==null?Integer.MAX_VALUE:r.pantryStatus().ordinal())
                .thenComparing(Result::pantryPercentage,Comparator.nullsLast(Comparator.reverseOrder()))
                .thenComparing(r->r.recipe().getName().toLowerCase(Locale.ROOT)).thenComparing(r->r.recipe().getId()));
        var ranked=new ArrayList<Result>();
        for(int i=0;i<results.size();i++) {var r=results.get(i);ranked.add(new Result(i+1,r.recipe(),r.score(),r.pantryStatus(),r.pantryPercentage(),r.reasons()));}
        var limitations=new ArrayList<String>();
        if(home && excluded>0) limitations.add("Some recipes were excluded because of conflicting preferences or incomplete ingredient, allergen or dietary information.");
        if(home && (!profile.getLegacyAllergies().isEmpty() || !profile.getLegacyDietaryRestrictions().isEmpty() || !profile.getDislikedIngredients().isEmpty()))
            limitations.add("Older food settings need review; recommendations are withheld until they can be evaluated.");
        if(home && profile.getPreferredMealGoals().contains(MealGoal.HIGH_PROTEIN)
                && results.stream().anyMatch(r->r.recipe().getEvaluation().proteinGramsPerServing()==null))
            limitations.add("Some recipes lack complete verified nutrition; they receive no High Protein ranking credit.");
        return new HomeRecommendationsResponse(policy.homePreferencesConfigured(profile),List.copyOf(limitations),
                new RecommendationsResponse(inventory.isEmpty(),candidates.size(),excluded,List.copyOf(ranked)));
    }
}
