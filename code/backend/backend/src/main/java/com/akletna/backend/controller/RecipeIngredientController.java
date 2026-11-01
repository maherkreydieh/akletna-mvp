package com.akletna.backend.controller;

import com.akletna.backend.dto.RecipeIngredientRequest;
import com.akletna.backend.dto.RecipeIngredientResponse;
import com.akletna.backend.service.RecipeIngredientService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/recipes/{recipeId}/ingredients")
public class RecipeIngredientController {

    private final RecipeIngredientService recipeIngredientService;

    public RecipeIngredientController(RecipeIngredientService recipeIngredientService) {
        this.recipeIngredientService = recipeIngredientService;
    }

    @PostMapping
    public ResponseEntity<RecipeIngredientResponse> addIngredientToRecipe(@PathVariable Long recipeId,
                                                                          @Valid @RequestBody RecipeIngredientRequest request,
                                                                          Authentication authentication) {
        String userEmail = authentication.getName();
        RecipeIngredientResponse response = recipeIngredientService.addIngredientToRecipe(recipeId, request, userEmail);
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<RecipeIngredientResponse>> getIngredientsForRecipe(@PathVariable Long recipeId,
                                                                                  Authentication authentication) {
        String userEmail = authentication.getName();
        List<RecipeIngredientResponse> response = recipeIngredientService.getIngredientsForRecipe(recipeId, userEmail);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{recipeIngredientId}")
    public ResponseEntity<RecipeIngredientResponse> updateRecipeIngredient(@PathVariable Long recipeId,
                                                                           @PathVariable Long recipeIngredientId,
                                                                           @Valid @RequestBody RecipeIngredientRequest request,
                                                                           Authentication authentication) {
        String userEmail = authentication.getName();
        RecipeIngredientResponse response = recipeIngredientService.updateRecipeIngredient(recipeId, recipeIngredientId, request, userEmail);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{recipeIngredientId}")
    public ResponseEntity<Void> removeIngredientFromRecipe(@PathVariable Long recipeId,
                                                           @PathVariable Long recipeIngredientId,
                                                           Authentication authentication) {
        String userEmail = authentication.getName();
        recipeIngredientService.removeIngredientFromRecipe(recipeId, recipeIngredientId, userEmail);
        return ResponseEntity.noContent().build();
    }
}