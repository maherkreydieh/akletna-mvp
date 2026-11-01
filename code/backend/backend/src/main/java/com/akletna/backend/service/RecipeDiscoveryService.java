package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service
public class RecipeDiscoveryService {
    public enum Collection { CURATED, COMMUNITY, MINE, SAVED }
    private final RecipeRepository recipes;
    private final SavedRecipeRepository saves;
    private final RecipeService recipeService;
    private final UserService users;
    private final RecipeEvaluationService evaluation;
    public RecipeDiscoveryService(RecipeRepository recipes,SavedRecipeRepository saves,RecipeService recipeService,
            UserService users,RecipeEvaluationService evaluation) {
        this.recipes=recipes;this.saves=saves;this.recipeService=recipeService;this.users=users;this.evaluation=evaluation;
    }
    @Transactional(readOnly=true)
    public List<RecipeResponse> list(Collection collection,String email,String category,Set<MealGoal> goals,DietaryPreference diet) {
        var user=users.getUserByEmail(email);
        List<SavedRecipe> saved=collection==Collection.SAVED ? saves.findReadableByUser(user.getId()):List.of();
        List<Recipe> rows=switch(collection) {
            case CURATED -> recipes.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.CURATED,RecipeVisibility.PUBLIC);
            case COMMUNITY -> recipes.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.USER,RecipeVisibility.PUBLIC);
            case MINE -> recipes.findByUserOrderByCreatedAtDesc(user).stream().filter(r->r.getOrigin()==RecipeOrigin.USER).toList();
            case SAVED -> saved.stream().map(SavedRecipe::getRecipe).toList();
        };
        var evaluations=evaluation.evaluate(user,rows);
        var responses=recipeService.mapCollection(rows);
        for(int i=0;i<responses.size();i++) {
            var response=responses.get(i);response.setEvaluation(evaluations.get(response.getId()));
            if(collection==Collection.SAVED) { response.setSaved(true);response.setSavedAt(saved.get(i).getSavedAt()); }
        }
        return responses.stream().filter(r->category==null || category.isBlank() || category.trim().equalsIgnoreCase(r.getCategory()))
                .filter(r->goals==null || goals.stream().allMatch(g->r.getEvaluation().mealGoals().get(g)==RecipeEvaluationResponse.GoalStatus.QUALIFIES))
                .filter(r->diet==null || r.getEvaluation().diets().get(diet)==CompatibilityStatus.COMPATIBLE).toList();
    }
    @Transactional(readOnly=true)
    public RecipeEvaluationResponse detail(Long id,String email) {
        var recipe=recipeService.getRecipeEntityAndVerifyReadable(id,email);
        return evaluation.evaluate(users.getUserByEmail(email),List.of(recipe)).get(id);
    }
}
