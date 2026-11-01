package com.akletna.backend;

import com.akletna.backend.dto.*;
import com.akletna.backend.dto.RecipeEvaluationResponse.*;
import com.akletna.backend.dto.PantryMatchesResponse.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.service.*;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class RecommendationTests {
    final RecommendationPolicy policy=new RecommendationPolicy();
    PreferencesResponse prefs() {return new PreferencesResponse(1L,Set.of(),Set.of(),Set.of(),Set.of());}
    RecipeResponse recipe() {var r=new RecipeResponse();r.setId(1L);r.setName("Meal");r.setOrigin(RecipeOrigin.CURATED);r.setVisibility(RecipeVisibility.PUBLIC);r.setSaved(false);r.setSaveCount(0L);return r;}
    RecipeEvaluationResponse evaluation(CompatibilityStatus state, List<RecipeEvaluationResponse.Reason> reasons) {
        return new RecipeEvaluationResponse(state,reasons,Map.of(DietaryPreference.VEGETARIAN,state,DietaryPreference.VEGAN,state),
                Map.of(MealGoal.BUDGET_FRIENDLY,GoalStatus.QUALIFIES,MealGoal.HIGH_PROTEIN,GoalStatus.QUALIFIES),new BigDecimal("25"),new BigDecimal("20"));
    }
    RecipeMatch pantry(String score) {return new RecipeMatch(1L,"Meal",RecipeOrigin.CURATED,RecipeVisibility.PUBLIC,1,0,null,
            MatchStatus.READY_TO_COOK,new BigDecimal(score),new Counts(1,0,0,0,0),List.of(),null);}
    BigDecimal points(RecommendationPolicy.Scored value,String code) {return value.reasons().stream().filter(r->r.code().equals(code)).map(RecommendationsResponse.Reason::points).reduce(BigDecimal.ZERO,BigDecimal::add);}
    void number(String expected,BigDecimal actual) {assertEquals(0,new BigDecimal(expected).compareTo(actual));}
    @Test void perfectFitHasAllDocumentedIndependentComponents() {
        var pref=prefs();pref.setDietaryRestrictions(Set.of("VEGETARIAN"));pref.setPreferredMealGoals(Set.of(MealGoal.BUDGET_FRIENDLY));
        var r=recipe();r.setSaved(true);var match=pantry("100.00");
        var value=policy.score(r,evaluation(CompatibilityStatus.COMPATIBLE,List.of()),pref,match);
        number("95",value.score());number("50",points(value,"PANTRY"));number("15",points(value,"DIET_VEGETARIAN"));
        number("15",points(value,"GOAL_BUDGET_FRIENDLY"));number("5",points(value,"SAVED"));number("10",points(value,"CONFIDENCE"));
        number("100",match.score());assertEquals("PANTRY",value.reasons().getFirst().code());
    }
    @Test void avoidanceIsEligibilityAndCannotBeBoughtByPerfectPantry() {
        var e=evaluation(CompatibilityStatus.CONFLICT,List.of(new RecipeEvaluationResponse.Reason("ALLERGEN_CONFLICT",Severity.AVOID,"Contains sesame",1L)));
        assertFalse(policy.eligible(e));number("100",pantry("100").score());
        var dietary=evaluation(CompatibilityStatus.CONFLICT,List.of(new RecipeEvaluationResponse.Reason("DIETARY_CONFLICT",Severity.AVOID,"Not vegetarian",null)));
        assertTrue(policy.eligible(dietary));var value=policy.score(recipe(),dietary,prefs(),pantry("100"));
        number("20",value.score());number("-30",points(value,"DIETARY_CONFLICT"));assertEquals("DIETARY_CONFLICT",value.reasons().getFirst().code());
    }
    @Test void unknownIsRetainedWithNoDietOrConfidenceCreditAndWarningFirst() {
        var p=prefs();p.setDietaryRestrictions(Set.of("VEGAN"));p.setAllergies(Set.of("SESAME"));
        var unknown=policy.score(recipe(),evaluation(CompatibilityStatus.UNKNOWN,List.of()),p,pantry("80"));
        var compatible=policy.score(recipe(),evaluation(CompatibilityStatus.COMPATIBLE,List.of()),p,pantry("80"));
        assertTrue(policy.eligible(evaluation(CompatibilityStatus.UNKNOWN,List.of())));number("40",unknown.score());number("65",compatible.score());
        number("0",points(unknown,"DIET_VEGAN"));number("0",points(unknown,"CONFIDENCE"));assertEquals("UNKNOWN",unknown.reasons().getFirst().code());
    }
    @Test void dietaryCreditIsSplitOnlyOverConfiguredVerifiableDiets() {
        var p=prefs();p.setDietaryRestrictions(Set.of("VEGETARIAN","VEGAN"));
        var e=new RecipeEvaluationResponse(CompatibilityStatus.UNKNOWN,List.of(),Map.of(DietaryPreference.VEGETARIAN,CompatibilityStatus.COMPATIBLE,DietaryPreference.VEGAN,CompatibilityStatus.UNKNOWN),Map.of(),null,new BigDecimal("20"));
        var value=policy.score(recipe(),e,p,null);number("7.5",points(value,"DIET_VEGETARIAN"));number("0",points(value,"DIET_VEGAN"));
    }
    @Test void goalsSplitProportionallyAndIncompleteProteinCannotEarnCredit() {
        var p=prefs();p.setPreferredMealGoals(Set.of(MealGoal.BUDGET_FRIENDLY,MealGoal.HIGH_PROTEIN));
        var e=new RecipeEvaluationResponse(CompatibilityStatus.COMPATIBLE,List.of(),Map.of(),Map.of(MealGoal.BUDGET_FRIENDLY,GoalStatus.QUALIFIES,MealGoal.HIGH_PROTEIN,GoalStatus.UNKNOWN),null,new BigDecimal("20"));
        var value=policy.score(recipe(),e,p,null);number("7.5",value.score());number("0",points(value,"GOAL_HIGH_PROTEIN"));
        assertTrue(value.reasons().stream().anyMatch(r->r.code().equals("GOAL_UNKNOWN_HIGH_PROTEIN")));
        number("15",policy.score(recipe(),evaluation(CompatibilityStatus.COMPATIBLE,List.of()),p,null).score());
    }
    @Test void savedBonusIsSmallAndPopularityUsesBoundedActualPublicUserCounts() {
        var r=recipe();r.setOrigin(RecipeOrigin.USER);r.setSaved(true);r.setSaveCount(2L);
        var e=evaluation(CompatibilityStatus.COMPATIBLE,List.of());var value=policy.score(r,e,prefs(),null);number("6",value.score());
        r.setSaveCount(Long.MAX_VALUE);number("10",policy.score(r,e,prefs(),null).score());
        r.setVisibility(RecipeVisibility.PRIVATE);number("5",policy.score(r,e,prefs(),null).score());
        r.setVisibility(RecipeVisibility.PUBLIC);r.setOrigin(RecipeOrigin.CURATED);number("5",policy.score(r,e,prefs(),null).score());
    }
    @Test void multipleDislikesHaveBoundedPenaltyAndRemainEligibleWithStableWarnings() {
        var reasons=new ArrayList<RecipeEvaluationResponse.Reason>();for(long id=4;id>=1;id--)reasons.add(new RecipeEvaluationResponse.Reason("DISLIKED_INGREDIENT",Severity.DISLIKE,"Dislike "+id,id));
        var e=evaluation(CompatibilityStatus.COMPATIBLE,reasons);assertTrue(policy.eligible(e));
        var value=policy.score(recipe(),e,prefs(),pantry("100"));number("35",value.score());number("-15",points(value,"DISLIKE"));
        assertEquals(4,value.reasons().stream().filter(r->r.code().equals("DISLIKE")).count());
        assertEquals(value,policy.score(recipe(),e,prefs(),pantry("100")));
        // A warning must remain visible in the card's first four reasons even with many dislikes.
        var unknown=policy.score(recipe(),evaluation(CompatibilityStatus.UNKNOWN,reasons),prefs(),pantry("100"));
        assertEquals("UNKNOWN",unknown.reasons().getFirst().code());
    }
    @Test void newUserHasNoMandatorySettingsAndEmptyPantryIsUnavailableNotZeroPercent() {
        var e=evaluation(CompatibilityStatus.COMPATIBLE,List.of());var unset=policy.score(recipe(),e,prefs(),null);
        number("0",unset.score());assertEquals("PANTRY_UNSET",unset.reasons().getFirst().code());
        number("21.175",points(policy.score(recipe(),e,prefs(),pantry("42.35")),"PANTRY"));
        number("50",policy.score(recipe(),e,prefs(),pantry("100")).score());
    }
    @Test void configurationAndClampingAreCentralizedAndRejectInvalidWeights() {
        policy.setPantryWeight(new BigDecimal("200"));number("100",policy.score(recipe(),evaluation(CompatibilityStatus.COMPATIBLE,List.of()),prefs(),pantry("100")).score());
        var e=evaluation(CompatibilityStatus.CONFLICT,List.of(new RecipeEvaluationResponse.Reason("DIETARY_CONFLICT",Severity.AVOID,"Conflict",null)));
        number("0",policy.score(recipe(),e,prefs(),null).score());
        assertThrows(IllegalArgumentException.class,()->policy.setDislikeCap(new BigDecimal("-1")));
        assertThrows(IllegalArgumentException.class,()->policy.setPopularitySaveCap(0));
    }
}
