package com.akletna.backend.controller;

import com.akletna.backend.dto.IngredientRequest;
import com.akletna.backend.dto.IngredientResponse;
import com.akletna.backend.service.IngredientService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/ingredients")
public class IngredientController {

    private final IngredientService ingredientService;

    public IngredientController(IngredientService ingredientService) {
        this.ingredientService = ingredientService;
    }

    @PostMapping
    public ResponseEntity<IngredientResponse> createIngredient(@Valid @RequestBody IngredientRequest request) {
        IngredientResponse created = ingredientService.createIngredient(request);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<IngredientResponse>> getAllIngredients() {
        List<IngredientResponse> ingredients = ingredientService.getAllIngredients();
        return ResponseEntity.ok(ingredients);
    }

    @GetMapping("/{id}")
    public ResponseEntity<IngredientResponse> getIngredientById(@PathVariable Long id) {
        IngredientResponse ingredient = ingredientService.getIngredientById(id);
        return ResponseEntity.ok(ingredient);
    }

}
