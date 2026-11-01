package com.akletna.backend.dto;
import com.akletna.backend.entity.*;
import java.math.BigDecimal;
import java.util.*;
public record RecipeEvaluationResponse(CompatibilityStatus compatibility,List<Reason> reasons,
        Map<DietaryPreference,CompatibilityStatus> diets,Map<MealGoal,GoalStatus> mealGoals,
        BigDecimal proteinGramsPerServing,BigDecimal highProteinThresholdGrams) {
    public enum GoalStatus { QUALIFIES, DOES_NOT_QUALIFY, UNKNOWN }
    public enum Severity { AVOID, UNCERTAIN, DISLIKE }
    public record Reason(String code,Severity severity,String message,Long ingredientId) {}
}
