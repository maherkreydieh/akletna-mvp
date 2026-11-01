package com.akletna.backend.repository;

import com.akletna.backend.entity.SavedRecipe;
import org.springframework.data.jpa.repository.*;
import java.util.List;

public interface SavedRecipeRepository extends JpaRepository<SavedRecipe, Long> {
    @Query("select s.recipe.id from SavedRecipe s where s.user.id=:userId and s.recipe.id in :ids")
    List<Long> savedIdsForUser(Long userId, List<Long> ids);
    boolean existsByUserIdAndRecipeId(Long userId, Long recipeId);
    @Query("select distinct s from SavedRecipe s join fetch s.recipe r left join fetch r.user left join fetch r.ingredients l left join fetch l.ingredient where s.user.id=:userId and (r.visibility=com.akletna.backend.entity.RecipeVisibility.PUBLIC or r.user.id=:userId) order by s.savedAt desc, s.id desc")
    List<SavedRecipe> findReadableByUser(Long userId);
    @Modifying
    @Query("delete from SavedRecipe s where s.user.id=:userId and s.recipe.id=:recipeId")
    int removeForUser(Long userId, Long recipeId);
    @Modifying
    @Query("delete from SavedRecipe s where s.recipe.id=:recipeId and s.user.id<>:ownerId")
    int removeOtherUsers(Long recipeId, Long ownerId);
    interface RecipeCount { Long getRecipeId(); Long getSaveCount(); }
    @Query("select s.recipe.id as recipeId, count(s) as saveCount from SavedRecipe s where s.recipe.id in :ids group by s.recipe.id")
    List<RecipeCount> countsForRecipes(List<Long> ids);
}
