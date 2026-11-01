package com.akletna.backend.service;

import com.akletna.backend.dto.MealPlanRequest;
import com.akletna.backend.dto.MealPlanResponse;
import com.akletna.backend.entity.MealPlan;
import com.akletna.backend.entity.Recipe;
import com.akletna.backend.entity.User;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.repository.MealPlanRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class MealPlanService {

    private final MealPlanRepository mealPlanRepository;
    private final UserService userService;
    private final RecipeService recipeService;

    public MealPlanService(MealPlanRepository mealPlanRepository,
                           UserService userService,
                           RecipeService recipeService) {
        this.mealPlanRepository = mealPlanRepository;
        this.userService = userService;
        this.recipeService = recipeService;
    }

    @org.springframework.transaction.annotation.Transactional(isolation = org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public MealPlanResponse createMealPlan(MealPlanRequest request, String userEmail) {
        User user = userService.getUserByEmail(userEmail);

        // Planning references a readable source; it never mutates that recipe.
        Recipe recipe = recipeService.getRecipeEntityAndVerifyReadable(request.getRecipeId(), userEmail);
        QuantityScaling.validateServings(recipe.getServings(), request.getPlannedServings());

        // Prevent booking the exact same meal slot on the same day
        if (mealPlanRepository.existsByUserAndDateAndMealType(user, request.getDate(), request.getMealType())) {
            throw new BadRequestException("A meal plan for " + request.getMealType() + " on " + request.getDate() + " already exists.");
        }

        MealPlan mealPlan = new MealPlan();
        mealPlan.setUser(user);
        mealPlan.captureRecipe(recipe);
        mealPlan.setPlannedServings(request.getPlannedServings());
        mealPlan.setDate(request.getDate());
        mealPlan.setMealType(request.getMealType());
        mealPlan.setCreatedAt(LocalDateTime.now());

        MealPlan saved = mealPlanRepository.save(mealPlan);
        return mapToResponse(saved);
    }

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public List<MealPlanResponse> getMealPlans(LocalDate startDate, LocalDate endDate, String userEmail) {
        if ((startDate == null) != (endDate == null))
            throw new BadRequestException("Provide both startDate and endDate, or neither.");
        User user = userService.getUserByEmail(userEmail);

        List<MealPlan> plans;
        if (startDate != null && endDate != null) {
            if (startDate.isAfter(endDate)) {
                throw new BadRequestException("startDate cannot be after endDate");
            }
            plans = mealPlanRepository.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(user, startDate, endDate);
        } else {
            plans = mealPlanRepository.findByUserOrderByDateAscMealTypeAsc(user);
        }

        return plans.stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public MealPlanResponse getMealPlanById(Long id, String userEmail) {
        MealPlan mealPlan = getMealPlanEntityAndVerifyOwner(id, userEmail);
        return mapToResponse(mealPlan);
    }

    @org.springframework.transaction.annotation.Transactional(isolation = org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public MealPlanResponse updateMealPlan(Long id, MealPlanRequest request, String userEmail) {
        MealPlan mealPlan = getMealPlanEntityAndVerifyOwner(id, userEmail);
        User user = mealPlan.getUser();

        boolean replacing = !mealPlan.getRecipe().getId().equals(request.getRecipeId());
        Recipe replacement = replacing ? recipeService.getRecipeEntityAndVerifyReadable(request.getRecipeId(), userEmail) : null;
        var snapshot = mealPlan.getSnapshot();
        if (!replacing && (snapshot == null || !snapshot.isReady()))
            throw new BadRequestException("This legacy planned meal is unresolved. Remove it and add a readable recipe again.");
        QuantityScaling.validateServings(replacing ? replacement.getServings() : snapshot.getBaseServings(), request.getPlannedServings());

        // Check if updating creates a conflict with an existing meal slot on that date
        if (mealPlanRepository.existsByUserAndDateAndMealTypeAndIdNot(user, request.getDate(), request.getMealType(), id)) {
            throw new BadRequestException("A meal plan for " + request.getMealType() + " on " + request.getDate() + " already exists.");
        }

        if (replacing) mealPlan.captureRecipe(replacement);
        mealPlan.setPlannedServings(request.getPlannedServings());
        mealPlan.setDate(request.getDate());
        mealPlan.setMealType(request.getMealType());

        MealPlan updated = mealPlanRepository.save(mealPlan);
        return mapToResponse(updated);
    }

    @org.springframework.transaction.annotation.Transactional
    public void deleteMealPlan(Long id, String userEmail) {
        MealPlan mealPlan = getMealPlanEntityAndVerifyOwner(id, userEmail);
        mealPlanRepository.delete(mealPlan);
    }

    public MealPlan getMealPlanEntityAndVerifyOwner(Long id, String userEmail) {
        User user = userService.getUserByEmail(userEmail);
        return mealPlanRepository.findByIdAndUser(id, user)
                .orElseThrow(() -> new ResourceNotFoundException("Meal plan not found with id: " + id));
    }

    private MealPlanResponse mapToResponse(MealPlan plan) {
        var snapshot = plan.getSnapshot();
        boolean ready = snapshot != null && snapshot.isReady();
        var response = new MealPlanResponse(
                plan.getId(),
                plan.getRecipe().getId(),
                ready ? snapshot.getName() : "Unresolved planned meal",
                ready ? snapshot.getCategory() : null,
                plan.getDate(),
                plan.getMealType(),
                plan.getCreatedAt()
        );
        response.setSnapshotState(ready ? "READY" : "UNRESOLVED");
        response.setRecipeBaseServings(ready ? snapshot.getBaseServings() : null);
        response.setRecipeImageUrl(ready ? snapshot.getImageUrl() : null);
        response.setPlannedServings(plan.getPlannedServings());
        return response;
    }
}
