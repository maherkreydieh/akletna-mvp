package com.akletna.backend;

import com.akletna.backend.entity.*;
import com.akletna.backend.dto.*;
import com.akletna.backend.dto.RecipeEvaluationResponse.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.*;
import com.akletna.backend.nutrition.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class RecipeEvaluationTests {
    UserPreferenceService preferences;IngredientClassificationRepository metadata;RecipeClassificationRepository budgets;IngredientNutritionRepository profiles;
    RecipeEvaluationService service;User user;PreferencesResponse pref;
    @BeforeEach void setup() {
        preferences=mock(UserPreferenceService.class);metadata=mock(IngredientClassificationRepository.class);budgets=mock(RecipeClassificationRepository.class);profiles=mock(IngredientNutritionRepository.class);
        service=new RecipeEvaluationService(preferences,metadata,budgets,profiles,new BigDecimal("20"));user=new User();user.setId(1L);
        pref=new PreferencesResponse(null,Set.of(),Set.of(),Set.of(),Set.of());when(preferences.forUser(user)).thenReturn(pref);
    }
    private Recipe recipe(long id,String name) {
        var ingredient=new Ingredient();ingredient.setId(id);ingredient.setName(name);ingredient.setUnit("g");
        var line=new RecipeIngredient();line.setIngredient(ingredient);line.setQuantity(new BigDecimal("100"));line.setUnit("g");
        var recipe=new Recipe();recipe.setId(id);recipe.setName(name);recipe.setServings(1);recipe.getIngredients().add(line);return recipe;
    }
    private IngredientClassification classification(Recipe recipe,CompatibilityStatus vegetarian,CompatibilityStatus vegan,boolean complete,Allergen... allergens) {
        var c=new IngredientClassification();c.setIngredient(recipe.getIngredients().getFirst().getIngredient());c.setVegetarian(vegetarian);c.setVegan(vegan);c.setAllergensComplete(complete);c.setAllergens(Set.of(allergens));return c;
    }
    private RecipeEvaluationResponse evaluate(Recipe recipe,IngredientClassification... classes) {
        when(metadata.findForIngredients(any())).thenReturn(Arrays.asList(classes));return service.evaluate(user,List.of(recipe)).get(recipe.getId());
    }
    @Test void structuredAllergenConflictOutranksUnknownAndDislikeWithDistinctSeverities() {
        pref.setAllergies(Set.of("SESAME"));pref.setDislikedIngredientIds(Set.of(1L));
        var r=recipe(1,"Different name");var c=classification(r,CompatibilityStatus.COMPATIBLE,CompatibilityStatus.COMPATIBLE,false,Allergen.SESAME);
        var result=evaluate(r,c);assertEquals(CompatibilityStatus.CONFLICT,result.compatibility());
        assertTrue(result.reasons().stream().anyMatch(reason->reason.message().equals("Contains sesame") && reason.severity()==Severity.AVOID));
        assertTrue(result.reasons().stream().anyMatch(reason->reason.code().equals("DISLIKED_INGREDIENT") && reason.severity()==Severity.DISLIKE));
        assertTrue(result.reasons().stream().anyMatch(reason->reason.code().equals("ALLERGEN_UNKNOWN")));
    }
    @Test void namesCannotProveSafetyOrCreateAllergenConflictsAndUnreviewedMetadataStaysUnknown() {
        pref.setAllergies(Set.of("DAIRY"));
        var r=recipe(1,"Milk free vegan chicken");assertEquals(CompatibilityStatus.UNKNOWN,evaluate(r).compatibility());
        var c=classification(r,CompatibilityStatus.COMPATIBLE,CompatibilityStatus.COMPATIBLE,true);
        var result=evaluate(r,c);assertEquals(CompatibilityStatus.COMPATIBLE,result.compatibility());assertTrue(result.reasons().isEmpty());
        pref.setDislikedIngredientIds(Set.of(2L));assertTrue(evaluate(r,c).reasons().isEmpty());
    }
    @ParameterizedTest @CsvSource({"VEGETARIAN,COMPATIBLE,COMPATIBLE","VEGETARIAN,CONFLICT,CONFLICT","VEGETARIAN,UNKNOWN,UNKNOWN","VEGAN,COMPATIBLE,COMPATIBLE","VEGAN,CONFLICT,CONFLICT","VEGAN,UNKNOWN,UNKNOWN"})
    void dietClassificationHasCompatibleConflictAndUnknown(String diet,CompatibilityStatus ingredientState,CompatibilityStatus expected) {
        pref.setDietaryRestrictions(Set.of(diet));var r=recipe(1,"No inference");
        var result=evaluate(r,classification(r,ingredientState,ingredientState,true));
        assertEquals(expected,result.compatibility());assertEquals(expected,result.diets().get(DietaryPreference.valueOf(diet)));
    }
    @Test void unresolvedLegacyRestrictionsAreUnknownAndLegacyDislikesAreNotResolvedByName() {
        pref.setLegacyAllergies(Set.of("custom allergy"));pref.setDislikedIngredients(Set.of("Ingredient"));
        var r=recipe(1,"Ingredient");var result=evaluate(r,classification(r,CompatibilityStatus.COMPATIBLE,CompatibilityStatus.COMPATIBLE,true));
        assertEquals(CompatibilityStatus.UNKNOWN,result.compatibility());assertTrue(result.reasons().stream().anyMatch(x->x.code().equals("LEGACY_RESTRICTION_UNKNOWN")));
        assertFalse(result.reasons().stream().anyMatch(x->x.code().equals("DISLIKED_INGREDIENT")));
    }
    @Test void dislikedIdentityIsSoftAndDoesNotTurnCompatibilityIntoAllergyConflict() {
        pref.setDislikedIngredientIds(Set.of(1L));var r=recipe(1,"Eggplant");var result=evaluate(r);
        assertEquals(CompatibilityStatus.COMPATIBLE,result.compatibility());assertEquals(Severity.DISLIKE,result.reasons().getFirst().severity());
    }
    private void nutrition(Recipe recipe,String protein) {
        var i=recipe.getIngredients().getFirst().getIngredient();i.setNutritionProvider(UsdaFoodClient.PROVIDER);i.setExternalFoodId("123");i.setPreparationState("cooked");
        var snapshot=mock(IngredientNutritionRepository.Snapshot.class);
        when(snapshot.getProvider()).thenReturn(UsdaFoodClient.PROVIDER);when(snapshot.getExternalFoodId()).thenReturn("123");when(snapshot.getPreparationState()).thenReturn("cooked");
        when(snapshot.getCaloriesKcal()).thenReturn(new BigDecimal("200"));when(snapshot.getProteinGrams()).thenReturn(new BigDecimal(protein));
        when(snapshot.getCarbohydratesGrams()).thenReturn(BigDecimal.TEN);when(snapshot.getFatGrams()).thenReturn(BigDecimal.ONE);
        when(profiles.findSnapshots(eq(UsdaFoodClient.PROVIDER),any())).thenReturn(List.of(snapshot));
    }
    @ParameterizedTest @CsvSource({"20,QUALIFIES","19.999999,DOES_NOT_QUALIFY","30,QUALIFIES"})
    void completeTrustedProteinUsesConfiguredPerServingThreshold(String protein,GoalStatus expected) {
        var r=recipe(1,"Protein");nutrition(r,protein);var result=evaluate(r);
        assertEquals(expected,result.mealGoals().get(MealGoal.HIGH_PROTEIN));assertEquals(new BigDecimal(protein).setScale(6),result.proteinGramsPerServing());
        var perServing=RecipeNutritionService.calculate(r,r.getIngredients(),identity->Optional.of(new Nutrients(new BigDecimal("200"),new BigDecimal(protein),BigDecimal.TEN,BigDecimal.ONE)));
        assertEquals(perServing.perServing().proteinGrams(),result.proteinGramsPerServing());
    }
    @Test void totalProteinIsNotPerServingAndIncompleteOrUserProvidedNutritionCannotQualify() {
        var r=recipe(1,"Protein");nutrition(r,"30");r.setServings(2);
        assertEquals(GoalStatus.DOES_NOT_QUALIFY,evaluate(r).mealGoals().get(MealGoal.HIGH_PROTEIN));
        r.getIngredients().getFirst().setUnit("cup");var result=evaluate(r);assertNull(result.proteinGramsPerServing());assertEquals(GoalStatus.UNKNOWN,result.mealGoals().get(MealGoal.HIGH_PROTEIN));
        r.getIngredients().getFirst().setUnit("g");r.getIngredients().getFirst().getIngredient().setNutritionProvider("USER_PROVIDED");
        assertEquals(GoalStatus.UNKNOWN,evaluate(r).mealGoals().get(MealGoal.HIGH_PROTEIN));
    }
    @Test void budgetFriendlyOnlyUsesReviewedCuratedClassificationAndCategoryIsIndependent() {
        var r=recipe(1,"Budget");r.setCategory("Yakhnet");
        var budget=new RecipeClassification();budget.setRecipe(r);budget.setBudgetFriendly(true);
        when(budgets.findAllById(any())).thenReturn(List.of(budget));
        assertEquals(GoalStatus.UNKNOWN,evaluate(r).mealGoals().get(MealGoal.BUDGET_FRIENDLY));
        r.setOrigin(RecipeOrigin.CURATED);assertEquals(GoalStatus.QUALIFIES,evaluate(r).mealGoals().get(MealGoal.BUDGET_FRIENDLY));
        budget.setBudgetFriendly(false);assertEquals(GoalStatus.DOES_NOT_QUALIFY,evaluate(r).mealGoals().get(MealGoal.BUDGET_FRIENDLY));assertEquals("Yakhnet",r.getCategory());
    }
    @Test void bulkEvaluationQueriesMetadataAndProfilesOnceAndDoesNotWrite() {
        var a=recipe(1,"First");var b=recipe(2,"Second");nutrition(a,"30");nutrition(b,"30");
        service.evaluate(user,List.of(a,b));
        verify(preferences,times(1)).forUser(user);verify(metadata,times(1)).findForIngredients(any());
        verify(budgets,times(1)).findAllById(any());verify(profiles,times(1)).findSnapshots(eq(UsdaFoodClient.PROVIDER),any());
        verifyNoMoreInteractions(preferences,metadata,budgets,profiles);
    }
    @Test void missingIngredientsAndInvalidServingsCannotClassifyProteinOrDiet() {
        var r=recipe(1,"Empty");r.getIngredients().clear();var result=evaluate(r);
        assertEquals(CompatibilityStatus.UNKNOWN,result.compatibility());assertEquals(GoalStatus.UNKNOWN,result.mealGoals().get(MealGoal.HIGH_PROTEIN));
        r=recipe(1,"Invalid servings");nutrition(r,"30");r.setServings(0);assertEquals(GoalStatus.UNKNOWN,evaluate(r).mealGoals().get(MealGoal.HIGH_PROTEIN));
    }
}
