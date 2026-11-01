package com.akletna.backend.repository;

import com.akletna.backend.entity.MealPlan;
import com.akletna.backend.entity.MealType;
import com.akletna.backend.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface MealPlanRepository extends JpaRepository<MealPlan, Long> {
    boolean existsByRecipeId(Long recipeId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"snapshot.ingredients"})
    List<MealPlan> findByUserOrderByDateAscMealTypeAsc(User user);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"snapshot.ingredients"})
    List<MealPlan> findByUserAndDateBetweenOrderByDateAscMealTypeAsc(User user, LocalDate startDate, LocalDate endDate);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths={"snapshot.ingredients"})
    Optional<MealPlan> findByIdAndUser(Long id, User user);

    boolean existsByUserAndDateAndMealType(User user, LocalDate date, MealType mealType);

    boolean existsByUserAndDateAndMealTypeAndIdNot(User user, LocalDate date, MealType mealType, Long id);
}
