package com.akletna.backend.controller;

import com.akletna.backend.dto.MealPlanRequest;
import com.akletna.backend.dto.MealPlanResponse;
import com.akletna.backend.service.MealPlanService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/meal-plans")
public class MealPlanController {

    private final MealPlanService mealPlanService;

    public MealPlanController(MealPlanService mealPlanService) {
        this.mealPlanService = mealPlanService;
    }

    @PostMapping
    public ResponseEntity<MealPlanResponse> createMealPlan(@Valid @RequestBody MealPlanRequest request,
                                                           Authentication authentication) {
        String userEmail = authentication.getName();
        MealPlanResponse created = mealPlanService.createMealPlan(request, userEmail);
        return new ResponseEntity<>(created, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<MealPlanResponse>> getMealPlans(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            Authentication authentication) {
        String userEmail = authentication.getName();
        List<MealPlanResponse> plans = mealPlanService.getMealPlans(startDate, endDate, userEmail);
        return ResponseEntity.ok(plans);
    }

    @GetMapping("/{id}")
    public ResponseEntity<MealPlanResponse> getMealPlanById(@PathVariable Long id,
                                                            Authentication authentication) {
        String userEmail = authentication.getName();
        MealPlanResponse plan = mealPlanService.getMealPlanById(id, userEmail);
        return ResponseEntity.ok(plan);
    }

    @PutMapping("/{id}")
    public ResponseEntity<MealPlanResponse> updateMealPlan(@PathVariable Long id,
                                                           @Valid @RequestBody MealPlanRequest request,
                                                           Authentication authentication) {
        String userEmail = authentication.getName();
        MealPlanResponse updated = mealPlanService.updateMealPlan(id, request, userEmail);
        return ResponseEntity.ok(updated);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMealPlan(@PathVariable Long id,
                                               Authentication authentication) {
        String userEmail = authentication.getName();
        mealPlanService.deleteMealPlan(id, userEmail);
        return ResponseEntity.noContent().build();
    }
}
