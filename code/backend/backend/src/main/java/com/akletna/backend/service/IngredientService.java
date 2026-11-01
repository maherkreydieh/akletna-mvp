package com.akletna.backend.service;

import com.akletna.backend.dto.IngredientRequest;
import com.akletna.backend.dto.IngredientResponse;
import com.akletna.backend.entity.Ingredient;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.repository.IngredientRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class IngredientService {

    private final IngredientRepository ingredientRepository;

    public IngredientService(IngredientRepository ingredientRepository) {
        this.ingredientRepository = ingredientRepository;
    }

    public IngredientResponse createIngredient(IngredientRequest request) {
        String trimmedName = request.getName().trim();

        if (ingredientRepository.existsByNameIgnoreCase(trimmedName)) {
            throw new BadRequestException("Ingredient with name '" + trimmedName + "' already exists");
        }

        Ingredient ingredient = new Ingredient();
        ingredient.setName(trimmedName);
        ingredient.setUnit(QuantityUnit.normalizeInput(request.getUnit()));

        Ingredient saved = ingredientRepository.save(ingredient);
        return mapToResponse(saved);
    }

    public List<IngredientResponse> getAllIngredients() {
        return ingredientRepository.findAll()
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public IngredientResponse getIngredientById(Long id) {
        Ingredient ingredient = getIngredientEntity(id);
        return mapToResponse(ingredient);
    }

    public Ingredient getIngredientEntity(Long id) {
        return ingredientRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ingredient not found with id: " + id));
    }

    private IngredientResponse mapToResponse(Ingredient ingredient) {
        return new IngredientResponse(
                ingredient.getId(),
                ingredient.getName(),
                ingredient.getUnit()
        );
    }
}
