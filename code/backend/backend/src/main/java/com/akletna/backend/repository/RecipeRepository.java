package com.akletna.backend.repository;

import com.akletna.backend.entity.Recipe;
import com.akletna.backend.entity.User;
import com.akletna.backend.entity.RecipeVisibility;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RecipeRepository extends JpaRepository<Recipe, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"user","ingredients","ingredients.ingredient"})
    @org.springframework.data.jpa.repository.Query("select r from Recipe r where r.id=:id")
    Optional<Recipe> findForGrocery(Long id);
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("select r from Recipe r where r.id=:id")
    Optional<Recipe> findLockedById(Long id);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"user", "ingredients", "ingredients.ingredient"})
    List<Recipe> findByOriginAndVisibilityOrderByCreatedAtDesc(com.akletna.backend.entity.RecipeOrigin origin, RecipeVisibility visibility);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"user", "ingredients", "ingredients.ingredient"})
    List<Recipe> findByUserOrVisibilityOrderByCreatedAtDesc(User user, RecipeVisibility visibility);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"user", "ingredients", "ingredients.ingredient"})
    List<Recipe> findByUserOrderByCreatedAtDesc(User user);

    Optional<Recipe> findByIdAndUser(Long id, User user);
}
