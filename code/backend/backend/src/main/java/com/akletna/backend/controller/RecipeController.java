package com.akletna.backend.controller;

import com.akletna.backend.dto.RecipeRequest;
import com.akletna.backend.dto.RecipeResponse;
import com.akletna.backend.service.RecipeService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/recipes")
public class RecipeController {

    private final RecipeService recipeService;
    private final com.akletna.backend.service.SavedRecipeService savedRecipes;
    private final com.akletna.backend.service.RecipeNutritionService nutritionService;
    private final com.akletna.backend.service.RecipeDiscoveryService discovery;

    public RecipeController(RecipeService recipeService, com.akletna.backend.service.RecipeNutritionService nutritionService,
                            com.akletna.backend.service.SavedRecipeService savedRecipes,
                            com.akletna.backend.service.RecipeDiscoveryService discovery) {
        this.discovery=discovery;
        this.savedRecipes = savedRecipes;
        this.nutritionService = nutritionService;
        this.recipeService = recipeService;
    }

    @PostMapping
    public ResponseEntity<RecipeResponse> createRecipe(@Valid @RequestBody RecipeRequest request,
                                                       Authentication authentication) {
        String userEmail = authentication.getName();
        RecipeResponse created = recipeService.createRecipe(request, userEmail);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<RecipeResponse>> getAllRecipes(Authentication authentication,
            @RequestParam(required=false) String category,
            @RequestParam(required=false,name="goal") java.util.Set<com.akletna.backend.entity.MealGoal> goals,
            @RequestParam(required=false) com.akletna.backend.entity.DietaryPreference diet) {
        List<RecipeResponse> recipes = discovery.list(com.akletna.backend.service.RecipeDiscoveryService.Collection.CURATED,authentication.getName(),category,goals,diet);
        return ResponseEntity.ok(recipes);
    }

    @GetMapping("/community")
    public ResponseEntity<List<RecipeResponse>> community(Authentication authentication,
            @RequestParam(required=false) String category,
            @RequestParam(required=false,name="goal") java.util.Set<com.akletna.backend.entity.MealGoal> goals,
            @RequestParam(required=false) com.akletna.backend.entity.DietaryPreference diet) {
        return ResponseEntity.ok(discovery.list(com.akletna.backend.service.RecipeDiscoveryService.Collection.COMMUNITY,authentication.getName(),category,goals,diet));
    }

    @GetMapping("/saved")
    public ResponseEntity<List<RecipeResponse>> saved(Authentication authentication) {
        return ResponseEntity.ok(discovery.list(com.akletna.backend.service.RecipeDiscoveryService.Collection.SAVED,authentication.getName(),null,null,null));
    }

    @PutMapping("/{id}/save")
    public ResponseEntity<Void> save(@PathVariable Long id, Authentication authentication) {
        savedRecipes.save(id, authentication.getName());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}/save")
    public ResponseEntity<Void> unsave(@PathVariable Long id, Authentication authentication) {
        savedRecipes.unsave(id, authentication.getName());
        return ResponseEntity.noContent().build();
    }

    // Planner retains the former owner-or-public recipe selection contract.
    @GetMapping("/available")
    public ResponseEntity<List<RecipeResponse>> available(Authentication authentication) {
        return ResponseEntity.ok(recipeService.getAllUserRecipes(authentication.getName()));
    }

    @GetMapping("/{id}/nutrition")
    public ResponseEntity<com.akletna.backend.dto.RecipeNutritionResponse> nutrition(@PathVariable Long id, Authentication authentication) {
        return ResponseEntity.ok(nutritionService.getNutrition(id, authentication.getName()));
    }

    @GetMapping("/mine")
    public ResponseEntity<List<RecipeResponse>> getMyRecipes(Authentication authentication) {
        return ResponseEntity.ok(discovery.list(com.akletna.backend.service.RecipeDiscoveryService.Collection.MINE,authentication.getName(),null,null,null));
    }

    @GetMapping("/{id}")
    public ResponseEntity<RecipeResponse> getRecipeById(@PathVariable Long id,
                                                        Authentication authentication) {
        String userEmail = authentication.getName();
        RecipeResponse recipe = recipeService.getRecipeById(id, userEmail);
        recipe.setEvaluation(discovery.detail(id,userEmail));
        return ResponseEntity.ok(recipe);
    }

    @PutMapping("/{id}")
    public ResponseEntity<RecipeResponse> updateRecipe(@PathVariable Long id,
                                                       @Valid @RequestBody RecipeRequest request,
                                                       Authentication authentication) {
        String userEmail = authentication.getName();
        RecipeResponse updated = recipeService.updateRecipe(id, request, userEmail);
        return ResponseEntity.ok(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRecipe(@PathVariable Long id,
                                             Authentication authentication) {
        String userEmail = authentication.getName();
        recipeService.deleteRecipe(id, userEmail);
        return ResponseEntity.noContent().build();
    }
}
