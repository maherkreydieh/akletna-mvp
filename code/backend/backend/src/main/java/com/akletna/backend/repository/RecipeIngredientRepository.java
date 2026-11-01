package com.akletna.backend.repository;

import com.akletna.backend.entity.RecipeIngredient;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RecipeIngredientRepository extends JpaRepository<RecipeIngredient, Long> {
    List<RecipeIngredient> findByRecipeId(Long recipeId);

    Optional<RecipeIngredient> findByIdAndRecipeId(Long id, Long recipeId);

    boolean existsByRecipeIdAndIngredientId(Long recipeId, Long ingredientId);
}