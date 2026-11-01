package com.akletna.backend;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.Recipe;
import com.akletna.backend.service.RecommendationPolicy;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class SavedCategoryRecommendationTests {
    private final RecommendationPolicy policy=new RecommendationPolicy();
    private Recipe stored(long id,String category) {
        var recipe=new Recipe();recipe.setId(id);recipe.setCategory(category);return recipe;
    }
    private RecipeResponse response(String category) {
        var recipe=new RecipeResponse();recipe.setCategory(category);return recipe;
    }
    private RecommendationPolicy.Scored base(String score) {
        return new RecommendationPolicy.Scored(new BigDecimal(score),List.of());
    }
    @Test void disabledByDefaultPreservesScoresAndUsesNoSavedCategories() {
        assertFalse(policy.isPersonalizedSignalsEnabled());
        assertTrue(policy.savedCategories(List.of(stored(1,"Soup")),Set.of(1L)).isEmpty());
        var base=base("10");assertSame(base,policy.savedCategoryAffinity(base,response("Soup"),Set.of("soup")));
    }
    @Test void onlySignedInUsersReadableSavedIdentitiesContribute() {
        policy.setPersonalizedSignalsEnabled(true);
        assertEquals(Set.of("soup"),policy.savedCategories(List.of(stored(1," Soup "),stored(2,"Dessert")),Set.of(1L,99L)));
        assertTrue(policy.savedCategories(List.of(stored(1,"Soup")),Set.of(2L)).isEmpty());
    }
    @Test void manySavesAndDuplicateCandidatesCannotMultiplyBonus() {
        policy.setPersonalizedSignalsEnabled(true);
        var categories=policy.savedCategories(List.of(stored(1,"SOUP"),stored(1,"SOUP"),stored(2,"soup")),Set.of(1L,2L));
        var result=policy.savedCategoryAffinity(base("10"),response(" Soup "),categories);
        assertEquals(new BigDecimal("15.00"),result.score());
        assertEquals(1,result.reasons().size());assertEquals("SAVED_CATEGORY",result.reasons().getFirst().code());
    }
    @Test void coldStartAndMissingOrUnmatchedCategoriesDoNotInventSignals() {
        policy.setPersonalizedSignalsEnabled(true);
        assertTrue(policy.savedCategories(List.of(stored(1,null),stored(2,"  ")),Set.of(1L,2L)).isEmpty());
        for(String category:Arrays.asList(null,"","Dessert")) {
            var base=base("12");assertSame(base,policy.savedCategoryAffinity(base,response(category),Set.of("soup")));
        }
    }
    @Test void scoreRemainsBoundedAndExistingReasonsArePreserved() {
        policy.setPersonalizedSignalsEnabled(true);
        var reason=new RecommendationsResponse.Reason("UNKNOWN","Information incomplete",BigDecimal.ZERO);
        var base=new RecommendationPolicy.Scored(new BigDecimal("99"),List.of(reason));
        var result=policy.savedCategoryAffinity(base,response("Soup"),Set.of("soup"));
        assertEquals(new BigDecimal("100.00"),result.score());assertSame(reason,result.reasons().getFirst());
        assertEquals(1,base.reasons().size());
    }
}
