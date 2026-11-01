package com.akletna.backend.service;

import com.akletna.backend.dto.RecipeResponse;
import com.akletna.backend.entity.*;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class SavedRecipeService {
    private final SavedRecipeRepository saves;
    private final RecipeRepository recipes;
    private final RecipeService recipeService;
    private final UserService users;
    public SavedRecipeService(SavedRecipeRepository saves, RecipeRepository recipes, RecipeService recipeService, UserService users) {
        this.saves=saves; this.recipes=recipes; this.recipeService=recipeService; this.users=users;
    }
    @Transactional
    public void save(Long recipeId, String email) {
        // Serialize saves with visibility changes/deletion and other saves of this recipe.
        Recipe recipe = recipes.findLockedById(recipeId).orElseThrow(() -> new ResourceNotFoundException("Recipe not found."));
        User user = users.getUserByEmail(email);
        if (recipe.getVisibility()!=RecipeVisibility.PUBLIC && (recipe.getUser()==null || !recipe.getUser().getId().equals(user.getId())))
            throw new ResourceNotFoundException("Recipe not found.");
        if (!saves.existsByUserIdAndRecipeId(user.getId(), recipeId)) saves.save(new SavedRecipe(user, recipe));
    }
    @Transactional
    public void unsave(Long recipeId, String email) {
        // Generic success even for missing/inaccessible recipes; reveals no private metadata.
        saves.removeForUser(users.getUserByEmail(email).getId(), recipeId);
    }
    @Transactional(readOnly = true)
    public List<RecipeResponse> list(String email) {
        var rows = saves.findReadableByUser(users.getUserByEmail(email).getId());
        var responses = recipeService.mapCollection(rows.stream().map(SavedRecipe::getRecipe).toList());
        for (int i=0; i<responses.size(); i++) {
            responses.get(i).setSaved(true); responses.get(i).setSavedAt(rows.get(i).getSavedAt());
        }
        return responses;
    }
}
