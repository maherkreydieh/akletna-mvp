package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.dto.RecommendationsResponse.Reason;
import com.akletna.backend.dto.RecipeEvaluationResponse.GoalStatus;
import com.akletna.backend.entity.*;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;

/** MVP weights are product policy, not probabilities or medical guidance. */
@Component
@ConfigurationProperties(prefix="akletna.recommendations")
public class RecommendationPolicy {
    private BigDecimal pantryWeight=new BigDecimal("50");
    private BigDecimal dietaryWeight=new BigDecimal("15");
    private BigDecimal goalWeight=new BigDecimal("15");
    private BigDecimal savedWeight=new BigDecimal("5");
    private BigDecimal popularityWeight=new BigDecimal("5");
    private BigDecimal confidenceWeight=new BigDecimal("10");
    private BigDecimal dislikePerIngredient=new BigDecimal("5");
    private BigDecimal dislikeCap=new BigDecimal("15");
    private BigDecimal dietaryConflictPenalty=new BigDecimal("30");
    private int popularitySaveCap=10;
    public record Scored(BigDecimal score,List<Reason> reasons) {}

    public boolean homePreferencesConfigured(PreferencesResponse p) {
        return !p.getAllergies().isEmpty() || !p.getDietaryRestrictions().isEmpty()
                || !p.getDislikedIngredientIds().isEmpty() || !p.getPreferredMealGoals().isEmpty()
                || !p.getPreferredCategories().isEmpty() || !p.getLegacyAllergies().isEmpty()
                || !p.getLegacyDietaryRestrictions().isEmpty() || !p.getDislikedIngredients().isEmpty();
    }

    /** Hard restrictions run before scoring. Unknown mandatory facts never imply safety. */
    public boolean homeEligible(RecipeEvaluationResponse e, PreferencesResponse p) {
        if (e == null || !p.getLegacyAllergies().isEmpty() || !p.getLegacyDietaryRestrictions().isEmpty()
                || !p.getDislikedIngredients().isEmpty()) return false;
        if (e.reasons().stream().anyMatch(r -> Set.of("ALLERGEN_CONFLICT", "ALLERGEN_UNKNOWN",
                "DIETARY_CONFLICT", "DIETARY_UNKNOWN", "NO_INGREDIENT_INFORMATION",
                "DISLIKED_INGREDIENT").contains(r.code()))) return false;
        return p.getDietaryRestrictions().stream().allMatch(d ->
                e.diets().get(DietaryPreference.valueOf(d)) == CompatibilityStatus.COMPATIBLE);
    }

    /** Home ranks only persisted preference signals, not pantry, popularity or invented behavior. */
    public Scored homeScore(RecipeResponse recipe, RecipeEvaluationResponse e, PreferencesResponse p) {
        var reasons = new ArrayList<Reason>();
        for (var diet : DietaryPreference.values()) {
            if (p.getDietaryRestrictions().contains(diet.name())
                    && e.diets().get(diet) == CompatibilityStatus.COMPATIBLE)
                add(reasons, "DIET_" + diet.name(), "Matches your " + diet.label() + " preference",
                        fraction(dietaryWeight, p.getDietaryRestrictions().size()));
        }
        for (var goal : new TreeSet<>(p.getPreferredMealGoals())) {
            boolean verified = e.mealGoals().get(goal) == GoalStatus.QUALIFIES
                    && (goal != MealGoal.HIGH_PROTEIN || e.proteinGramsPerServing() != null);
            if (verified) add(reasons, "GOAL_" + goal.name(), "Matches your " + goal.label() + " goal",
                    fraction(goalWeight, p.getPreferredMealGoals().size()));
        }
        if (recipe.getCategory() != null && p.getPreferredCategories().stream()
                .anyMatch(c -> c.equalsIgnoreCase(recipe.getCategory())))
            add(reasons, "CATEGORY", "Matches a preferred recipe category", BigDecimal.TEN);
        if (reasons.isEmpty()) add(reasons, "SELECTION", homePreferencesConfigured(p)
                ? "Selected after checking your saved food preferences"
                : "General selection; configure Food Preferences to personalize it", BigDecimal.ZERO);
        var total = reasons.stream().map(Reason::points).reduce(BigDecimal.ZERO, BigDecimal::add)
                .min(new BigDecimal("100")).setScale(2, RoundingMode.HALF_UP);
        return new Scored(total, List.copyOf(reasons));
    }

    public boolean eligible(RecipeEvaluationResponse evaluation) {
        return evaluation.reasons().stream().noneMatch(r->r.code().equals("ALLERGEN_CONFLICT"));
    }

    public Scored score(RecipeResponse recipe,RecipeEvaluationResponse evaluation,
            PreferencesResponse preferences,PantryMatchesResponse.RecipeMatch pantry) {
        var reasons=new ArrayList<Reason>();
        if(pantry!=null) {
            add(reasons,"PANTRY",pantry.status()==PantryMatchesResponse.MatchStatus.READY_TO_COOK
                    ? "You have everything needed" : pantry.score().toPlainString()+"% pantry match",
                    pantry.score().multiply(pantryWeight).divide(new BigDecimal("100")));
        } else add(reasons,"PANTRY_UNSET","Add pantry ingredients for better recommendations.",BigDecimal.ZERO);
        int dietCount=preferences.getDietaryRestrictions().size();
        for(var diet:DietaryPreference.values()) if(preferences.getDietaryRestrictions().contains(diet.name())
                && evaluation.diets().get(diet)==CompatibilityStatus.COMPATIBLE)
            add(reasons,"DIET_"+diet.name(),"Matches your "+diet.label()+" preference",fraction(dietaryWeight,dietCount));
        if(evaluation.reasons().stream().anyMatch(r->r.code().equals("DIETARY_CONFLICT")))
            add(reasons,"DIETARY_CONFLICT","Conflicts with your configured dietary preference",dietaryConflictPenalty.negate());
        for(var goal:new TreeSet<>(preferences.getPreferredMealGoals())) {
            if(evaluation.mealGoals().get(goal)==GoalStatus.QUALIFIES)
                add(reasons,"GOAL_"+goal.name(),"Matches your "+goal.label()+" goal",fraction(goalWeight,preferences.getPreferredMealGoals().size()));
            else if(evaluation.mealGoals().get(goal)==GoalStatus.UNKNOWN)
                add(reasons,"GOAL_UNKNOWN_"+goal.name(),goal.label()+" cannot be verified from trusted data",BigDecimal.ZERO);
        }
        if(Boolean.TRUE.equals(recipe.getSaved())) add(reasons,"SAVED","Saved by you",savedWeight);
        if(recipe.getOrigin()==RecipeOrigin.USER && recipe.getVisibility()==RecipeVisibility.PUBLIC
                && recipe.getSaveCount()!=null && recipe.getSaveCount()>0)
            add(reasons,"POPULARITY","Popular in Community",popularityWeight.multiply(BigDecimal.valueOf(Math.min(recipe.getSaveCount(),popularitySaveCap)))
                    .divide(BigDecimal.valueOf(popularitySaveCap),6,RoundingMode.HALF_UP));
        boolean configured=!preferences.getAllergies().isEmpty() || !preferences.getDietaryRestrictions().isEmpty();
        if(evaluation.compatibility()==CompatibilityStatus.COMPATIBLE && configured)
            add(reasons,"CONFIDENCE","Reviewed information matches your configured dietary settings",confidenceWeight);
        if(evaluation.compatibility()==CompatibilityStatus.UNKNOWN || evaluation.reasons().stream().anyMatch(r->r.severity()==RecipeEvaluationResponse.Severity.UNCERTAIN))
            add(reasons,"UNKNOWN","Some dietary/allergen information is incomplete.",BigDecimal.ZERO);
        var dislikes=evaluation.reasons().stream().filter(r->r.code().equals("DISLIKED_INGREDIENT"))
                .sorted(Comparator.comparing(RecipeEvaluationResponse.Reason::ingredientId)).toList();
        BigDecimal remaining=dislikeCap;
        for(var dislike:dislikes) {
            var penalty=dislikePerIngredient.min(remaining);remaining=remaining.subtract(penalty);
            add(reasons,"DISLIKE",dislike.message(),penalty.negate());
        }
        evaluation.reasons().stream().filter(r->r.code().equals("LEGACY_DISLIKE_UNRESOLVED"))
                .forEach(r->add(reasons,r.code(),r.message(),BigDecimal.ZERO));
        var total=reasons.stream().map(Reason::points).reduce(BigDecimal.ZERO,BigDecimal::add)
                .max(BigDecimal.ZERO).min(new BigDecimal("100")).setScale(2,RoundingMode.HALF_UP);
        reasons.sort(Comparator.comparingInt((Reason r)->reasonPriority(r.code()))
                .thenComparing(r->r.points().abs(),Comparator.reverseOrder()).thenComparing(Reason::code).thenComparing(Reason::message));
        return new Scored(total,List.copyOf(reasons));
    }
    private int reasonPriority(String code) { return switch(code) { case "UNKNOWN" -> 0;case "DIETARY_CONFLICT" -> 1;case "DISLIKE" -> 2;default -> 3; }; }
    private static BigDecimal fraction(BigDecimal weight,int count) { return weight.divide(BigDecimal.valueOf(count),6,RoundingMode.HALF_UP); }
    private static void add(List<Reason> reasons,String code,String message,BigDecimal points) { reasons.add(new Reason(code,message,points)); }
    private BigDecimal valid(BigDecimal value) { if(value==null || value.signum()<0) throw new IllegalArgumentException("Recommendation weights must be nonnegative");return value; }
    public BigDecimal getPantryWeight(){return pantryWeight;} public void setPantryWeight(BigDecimal v){pantryWeight=valid(v);}
    public BigDecimal getDietaryWeight(){return dietaryWeight;} public void setDietaryWeight(BigDecimal v){dietaryWeight=valid(v);}
    public BigDecimal getGoalWeight(){return goalWeight;} public void setGoalWeight(BigDecimal v){goalWeight=valid(v);}
    public BigDecimal getSavedWeight(){return savedWeight;} public void setSavedWeight(BigDecimal v){savedWeight=valid(v);}
    public BigDecimal getPopularityWeight(){return popularityWeight;} public void setPopularityWeight(BigDecimal v){popularityWeight=valid(v);}
    public BigDecimal getConfidenceWeight(){return confidenceWeight;} public void setConfidenceWeight(BigDecimal v){confidenceWeight=valid(v);}
    public BigDecimal getDislikePerIngredient(){return dislikePerIngredient;} public void setDislikePerIngredient(BigDecimal v){dislikePerIngredient=valid(v);}
    public BigDecimal getDislikeCap(){return dislikeCap;} public void setDislikeCap(BigDecimal v){dislikeCap=valid(v);}
    public BigDecimal getDietaryConflictPenalty(){return dietaryConflictPenalty;} public void setDietaryConflictPenalty(BigDecimal v){dietaryConflictPenalty=valid(v);}
    public int getPopularitySaveCap(){return popularitySaveCap;} public void setPopularitySaveCap(int v){if(v<=0)throw new IllegalArgumentException("Popularity cap must be positive");popularitySaveCap=v;}
}
