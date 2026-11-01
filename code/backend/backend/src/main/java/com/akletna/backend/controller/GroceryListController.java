package com.akletna.backend.controller;

import com.akletna.backend.dto.GroceryGenerateRequest;
import com.akletna.backend.dto.GroceryItemResponse;
import com.akletna.backend.dto.GroceryListResponse;
import com.akletna.backend.service.GroceryListService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/grocery-list")
public class GroceryListController {

    private final GroceryListService groceryListService;

    public GroceryListController(GroceryListService groceryListService) {
        this.groceryListService = groceryListService;
    }

    @GetMapping("/from-recipe/{recipeId}")
    public com.akletna.backend.dto.RecipeShortageResponse preview(@PathVariable Long recipeId,
            @RequestParam Integer servings,Authentication authentication) {
        return groceryListService.previewShortages(recipeId,servings,authentication.getName());
    }
    @PostMapping("/from-recipe/{recipeId}")
    public com.akletna.backend.dto.RecipeShortageResponse add(@PathVariable Long recipeId,
            @jakarta.validation.Valid @RequestBody com.akletna.backend.dto.RecipeShortageRequest request,Authentication authentication) {
        return groceryListService.addShortages(recipeId,request.getServings(),authentication.getName());
    }
    @DeleteMapping("/contributions/{id}")
    public GroceryListResponse remove(@PathVariable Long id,Authentication authentication) {
        return groceryListService.removeContribution(id,authentication.getName());
    }

    @GetMapping
    public ResponseEntity<GroceryListResponse> getGroceryList(Authentication authentication) {
        String userEmail = authentication.getName();
        GroceryListResponse response = groceryListService.getOrCreateUserGroceryList(userEmail);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/generate")
    public ResponseEntity<GroceryListResponse> generateGroceryList(
            @RequestBody(required = false) GroceryGenerateRequest request,
            Authentication authentication) {
        String userEmail = authentication.getName();
        GroceryListResponse response = groceryListService.generateFromMealPlans(request, userEmail);
        return ResponseEntity.ok(response);
    }

    @PatchMapping("/items/{itemId}/toggle")
    public ResponseEntity<GroceryItemResponse> toggleItemCheck(
            @PathVariable Long itemId,
            Authentication authentication) {
        String userEmail = authentication.getName();
        GroceryItemResponse response = groceryListService.toggleItemChecked(itemId, userEmail);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping
    public ResponseEntity<Void> clearGroceryList(Authentication authentication) {
        String userEmail = authentication.getName();
        groceryListService.clearGroceryList(userEmail);
        return ResponseEntity.noContent().build();
    }
}
