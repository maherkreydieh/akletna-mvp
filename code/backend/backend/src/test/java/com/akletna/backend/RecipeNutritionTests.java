package com.akletna.backend;

import com.akletna.backend.entity.*;
import com.akletna.backend.nutrition.*;
import com.akletna.backend.repository.RecipeIngredientRepository;
import com.akletna.backend.service.*;
import com.akletna.backend.dto.RecipeNutritionResponse.Status;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class RecipeNutritionTests {
    @Test void identicalFoodIdentitiesUseOneStoredLookupAndNoSharedCache() {
        recipe(2,line("100","g",true),line("50","g",true));
        var result=service.getNutrition(11L,"owner");
        assertEquals(0,d("180").compareTo(result.totals().caloriesKcal()));
        verify(provider,times(1)).per100Grams(any());
        service.getNutrition(11L,"owner");
        verify(provider,times(2)).per100Grams(any());
    }
    @Test void rawAndCookedProfilesNeverShareCachedValues() {
        var raw=line("100","g",true);var cooked=line("100","g",true);
        cooked.getIngredient().setPreparationState("cooked");
        recipe(2,raw,cooked);
        when(provider.per100Grams(new FoodIdentity("TEST_ONLY","fixture-1","cooked")))
            .thenReturn(Optional.of(new Nutrients(d("240"),d("20"),d("30"),d("4"))));
        var result=service.getNutrition(11L,"owner");
        assertEquals(Status.COMPLETE,result.status());
        assertEquals(0,d("360").compareTo(result.totals().caloriesKcal()));
        assertEquals(0,d("180").compareTo(result.perServing().caloriesKcal()));
        verify(provider).per100Grams(new FoodIdentity("TEST_ONLY","fixture-1","raw"));
        verify(provider).per100Grams(new FoodIdentity("TEST_ONLY","fixture-1","cooked"));
    }
    @Test void brokenIngredientReferenceIsUnavailableNotAServerError() {
        var broken=line("100","g",false);broken.setIngredient(null);recipe(2,broken);
        var result=service.getNutrition(11L,"owner");
        assertEquals(Status.UNAVAILABLE,result.status());assertNull(result.totals());
        assertEquals("MISSING_INGREDIENT",result.issues().getFirst().reason());verifyNoInteractions(provider);
    }
    @Test void partialMappingDoesNotExposeKnownContributionAsCompleteTotals() {
        recipe(2,line("100","g",true),line("50","g",false));
        var result=service.getNutrition(11L,"owner");
        assertEquals(Status.INCOMPLETE,result.status());assertNull(result.totals());assertNull(result.perServing());
        assertEquals("MISSING_MAPPING",result.issues().getFirst().reason());
    }
    @Test void normalizedVolumeRemainsIncompleteEvenWithTrustedProfileAvailable() {
        recipe(2,line("100","g",true),line("0.75",QuantityUnit.normalizeInput("l"),true));
        var result = service.getNutrition(11L,"owner");
        assertEquals(Status.INCOMPLETE,result.status()); assertNull(result.totals()); assertNull(result.perServing());
        assertEquals("UNSUPPORTED_QUANTITY_OR_UNIT",result.issues().getFirst().reason());
        verify(provider,times(1)).per100Grams(any());
    }
    // Synthetic arithmetic fixtures only, never persisted or used by the app.
    private final Nutrients fixture = new Nutrients(d("120"), d("10"), d("15"), d("2"));
    private final RecipeService recipes = mock(RecipeService.class);
    private final RecipeIngredientRepository lines = mock(RecipeIngredientRepository.class);
    private final NutritionProvider provider = mock(NutritionProvider.class);
    private final RecipeNutritionService service = new RecipeNutritionService(recipes, lines, provider);
    private static BigDecimal d(String value) { return new BigDecimal(value); }

    private RecipeIngredient line(String quantity, String unit, boolean mapped) {
        Ingredient ingredient = new Ingredient();
        if (mapped) {
            ingredient.setNutritionProvider("TEST_ONLY"); ingredient.setExternalFoodId("fixture-1"); ingredient.setPreparationState("raw");
        }
        RecipeIngredient line = new RecipeIngredient(); line.setId(21L); line.setIngredient(ingredient);
        line.setQuantity(d(quantity)); line.setUnit(unit); return line;
    }
    private void recipe(Integer servings, RecipeIngredient... items) {
        Recipe recipe = new Recipe(); recipe.setServings(servings);
        when(recipes.getRecipeEntityAndVerifyReadable(11L, "owner")).thenReturn(recipe);
        when(lines.findByRecipeId(11L)).thenReturn(List.of(items));
        when(provider.per100Grams(new FoodIdentity("TEST_ONLY", "fixture-1", "raw"))).thenReturn(Optional.of(fixture));
    }

    @Test void sumsExactDecimalMassAndDividesByActualServings() {
        recipe(3, line("0.1", "kg", true), line("50.25", "g", true));
        var result = service.getNutrition(11L, "owner");
        assertEquals(Status.COMPLETE, result.status());
        assertEquals(0, d("180.3").compareTo(result.totals().caloriesKcal()));
        assertEquals(0, d("5.008333").compareTo(result.perServing().proteinGrams()));
        assertEquals(0, d("1.001667").compareTo(result.perServing().fatGrams()));
    }
    @Test void supportedMassConversionIsExactAndNeverGuessesVolumeOrCount() {
        assertEquals(0, d("125").compareTo(RecipeNutritionService.grams(d("0.125000"), " KG ")));
        for (String unit : List.of("cup", "piece", "clove", "mL", "L", "")) assertNull(RecipeNutritionService.grams(d("1"), unit));
        assertNull(RecipeNutritionService.grams(d("0"), "g"));
    }
    @Test void missingMappingAndUnavailableProviderDoNotReturnZeroMacros() {
        recipe(2, line("100", "g", false));
        var result = service.getNutrition(11L, "owner");
        assertEquals(Status.UNAVAILABLE, result.status()); assertNull(result.totals()); assertNull(result.perServing());
        assertEquals("MISSING_MAPPING", result.issues().getFirst().reason()); verifyNoInteractions(provider);
        recipe(2, line("100", "g", true));
        when(provider.per100Grams(any())).thenReturn(Optional.empty());
        assertEquals(Status.UNAVAILABLE, service.getNutrition(11L, "owner").status());
    }
    @Test void oneUnknownLineMakesEntireNutritionIncompleteWithoutPartialTotals() {
        recipe(2, line("100", "g", true), line("1", "cup", true));
        var result = service.getNutrition(11L, "owner");
        assertEquals(Status.INCOMPLETE, result.status()); assertNull(result.totals()); assertNull(result.perServing());
    }
    @Test void legacyUnknownServingsAndEmptyRecipeNeverInventServingCountsOrTotals() {
        recipe(null, line("100", "g", true));
        var result = service.getNutrition(11L, "owner");
        assertEquals(Status.INCOMPLETE, result.status()); assertNull(result.perServing());
        assertEquals("INVALID_SERVINGS", result.issues().getFirst().reason());
        recipe(2); assertEquals(Status.UNAVAILABLE, service.getNutrition(11L, "owner").status());
    }
    @Test void preparationIdentityIsPartOfProviderLookupAndDefaultSourceIsUnavailable() {
        recipe(2, line("100", "g", true));
        service.getNutrition(11L, "owner");
        verify(provider).per100Grams(new FoodIdentity("TEST_ONLY", "fixture-1", "raw"));
        assertTrue(new UnavailableNutritionProvider().per100Grams(new FoodIdentity("TEST_ONLY", "fixture-1", "cooked")).isEmpty());
    }
}
