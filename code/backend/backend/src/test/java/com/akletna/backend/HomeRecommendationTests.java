package com.akletna.backend;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.*;
import com.akletna.backend.nutrition.UsdaFoodClient;
import org.junit.jupiter.api.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

/** Real recommendation/evaluation/preference services, isolated repository fixtures; no database. */
class HomeRecommendationTests {
    final UserService users=mock(UserService.class);
    final UserRepository userRows=mock(UserRepository.class);
    final UserPreferenceRepository preferenceRows=mock(UserPreferenceRepository.class);
    final IngredientRepository ingredients=mock(IngredientRepository.class);
    final RecipeRepository recipes=mock(RecipeRepository.class);
    final SavedRecipeRepository saves=mock(SavedRecipeRepository.class);
    final PantryItemRepository pantry=mock(PantryItemRepository.class);
    final IngredientClassificationRepository classes=mock(IngredientClassificationRepository.class);
    final RecipeClassificationRepository budgets=mock(RecipeClassificationRepository.class);
    final IngredientNutritionRepository nutrition=mock(IngredientNutritionRepository.class);
    final User owner=new User(), other=new User();
    final List<Recipe> catalog=new ArrayList<>();
    final List<IngredientClassification> classifications=new ArrayList<>();
    UserPreference profile;
    UserPreferenceService preferences;
    RecommendationService service;
    RecommendationPolicy policy;

    @BeforeEach void setup() {
        owner.setId(1L);owner.setEmail("owner@example.test");
        other.setId(2L);other.setEmail("other@example.test");
        when(users.getUserByEmail(owner.getEmail())).thenReturn(owner);
        when(users.getUserByEmail(other.getEmail())).thenReturn(other);
        profile=new UserPreference(owner);
        when(preferenceRows.findByUser(owner)).thenAnswer(call->Optional.of(profile));
        when(preferenceRows.findByUser(other)).thenReturn(Optional.empty());
        when(preferenceRows.save(any())).thenAnswer(call->call.getArgument(0));
        when(userRows.findLockedById(1L)).thenReturn(Optional.of(owner));
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(any(),eq(RecipeVisibility.PUBLIC)))
            .thenAnswer(call->catalog.stream().filter(r->r.getUser()==call.getArgument(0)
                    || r.getVisibility()==RecipeVisibility.PUBLIC).toList());
        when(classes.findForIngredients(any())).thenAnswer(call->List.copyOf(classifications));
        preferences=new UserPreferenceService(preferenceRows,users,userRows,ingredients);
        var evaluation=new RecipeEvaluationService(preferences,classes,budgets,nutrition,new BigDecimal("20"));
        var recipeService=new RecipeService(recipes,users,mock(IngredientService.class),mock(MealPlanRepository.class),saves);
        var matching=new PantryMatchingService(users,recipeService,pantry,evaluation);
        policy=new RecommendationPolicy();
        service=new RecommendationService(users,recipeService,preferences,evaluation,pantry,matching,saves,policy);
    }

    Recipe recipe(long id,String name) {
        var ingredient=new Ingredient();ingredient.setId(id);ingredient.setName(name);ingredient.setUnit("g");
        var line=new RecipeIngredient();line.setIngredient(ingredient);line.setQuantity(new BigDecimal("100"));line.setUnit("g");
        var recipe=new Recipe();recipe.setId(id);recipe.setName(name);recipe.setUser(owner);recipe.setServings(1);
        recipe.setVisibility(RecipeVisibility.PUBLIC);recipe.getIngredients().add(line);catalog.add(recipe);
        return recipe;
    }
    IngredientClassification reviewed(Recipe recipe,CompatibilityStatus vegan,boolean complete,Allergen... allergens) {
        var c=new IngredientClassification();c.setIngredient(recipe.getIngredients().getFirst().getIngredient());
        c.setVegan(vegan);c.setVegetarian(vegan);c.setAllergensComplete(complete);c.setAllergens(Set.of(allergens));
        c.setReviewedAt(Instant.parse("2026-01-01T00:00:00Z"));classifications.add(c);return c;
    }
    HomeRecommendationsResponse home() {return service.recommendHome(owner.getEmail(),null,null,null);}
    List<Long> ids(HomeRecommendationsResponse response) {return response.selection().recommendations().stream().map(r->r.recipe().getId()).toList();}

    @Test void optionalSavedAffinityRanksOnlyEligibleRecipesAndRemainsUserScoped() {
        policy.setPersonalizedSignalsEnabled(true);
        recipe(1,"Alpha").setCategory("Main");
        var saved=recipe(2,"Saved soup");saved.setCategory("Soup");
        var similar=recipe(3,"Z soup");similar.setCategory("soup");
        when(saves.savedIdsForUser(eq(1L),any())).thenReturn(List.of(2L));
        assertEquals(List.of(2L,3L,1L),ids(home()));
        profile.setDislikedIngredientRefs(Set.of(similar.getIngredients().getFirst().getIngredient()));
        assertEquals(List.of(2L,1L),ids(home()));
        var otherResult=service.recommendHome(other.getEmail(),null,null,null);
        assertTrue(otherResult.selection().recommendations().stream().flatMap(r->r.reasons().stream())
                .noneMatch(r->r.code().equals("SAVED_CATEGORY")));
    }

    @Test void allergiesExcludeKnownConflictsAndIncompleteAllergensBeforeAnyRanking() {
        profile.setAllergies(Set.of("SESAME"));
        reviewed(recipe(1,"Conflicting"),CompatibilityStatus.COMPATIBLE,true,Allergen.SESAME);
        reviewed(recipe(2,"Unreviewed"),CompatibilityStatus.COMPATIBLE,false);
        reviewed(recipe(3,"Reviewed"),CompatibilityStatus.COMPATIBLE,true);
        assertEquals(List.of(3L),ids(home()));assertEquals(2,home().selection().excludedRecipeCount());
        assertFalse(home().limitations().isEmpty());
    }
    @Test void configuredDietsRequireReviewedCompatibilityAndNeverFallBackToConflicts() {
        profile.setDietaryRestrictions(Set.of("VEGAN"));
        reviewed(recipe(1,"Conflict"),CompatibilityStatus.CONFLICT,true);
        reviewed(recipe(2,"Unknown"),CompatibilityStatus.UNKNOWN,true);
        assertTrue(home().selection().recommendations().isEmpty());
        reviewed(recipe(3,"Compatible"),CompatibilityStatus.COMPATIBLE,true);
        assertEquals(List.of(3L),ids(home()));
    }
    @Test void dislikesUseIngredientIdentityAndExcludeInsteadOfMatchingNames() {
        var a=recipe(1,"Same name");recipe(2,"Same name");
        profile.setDislikedIngredientRefs(Set.of(a.getIngredients().getFirst().getIngredient()));
        assertEquals(List.of(2L),ids(home()));
    }
    @Test void noPreferencesIsExplicitGeneralSelectionAndTiesUseNameThenIdWithoutDuplicates() {
        var a=recipe(2,"ALPHA");recipe(1,"alpha");catalog.add(a);
        assertFalse(home().preferencesConfigured());assertEquals(List.of(1L,2L),ids(home()));
        assertEquals(2,home().selection().readableRecipeCount());
    }
    @Test void emptyIngredientsAreExcludedWhileUnknownNutritionGetsNoGoalCredit() {
        profile.setPreferredMealGoals(Set.of(MealGoal.HIGH_PROTEIN));
        recipe(1,"Empty").getIngredients().clear();recipe(2,"Missing nutrition");
        var result=home();assertEquals(List.of(2L),ids(result));
        assertEquals(0,result.selection().recommendations().getFirst().score().signum());
        assertNull(result.selection().recommendations().getFirst().recipe().getEvaluation().proteinGramsPerServing());
        assertTrue(result.limitations().stream().anyMatch(s->s.contains("nutrition")));
    }
    @Test void verifiedProteinGoalOutranksAlphabeticalOrderAndUnsupportedUnitsCannotEarnCredit() {
        profile.setPreferredMealGoals(Set.of(MealGoal.HIGH_PROTEIN));
        recipe(1,"Alpha unknown");var trusted=recipe(2,"Z verified");
        var ingredient=trusted.getIngredients().getFirst().getIngredient();
        ingredient.setNutritionProvider(UsdaFoodClient.PROVIDER);ingredient.setExternalFoodId("123");ingredient.setPreparationState("cooked");
        var snapshot=mock(IngredientNutritionRepository.Snapshot.class);
        when(snapshot.getProvider()).thenReturn(UsdaFoodClient.PROVIDER);when(snapshot.getExternalFoodId()).thenReturn("123");
        when(snapshot.getPreparationState()).thenReturn("cooked");when(snapshot.getCaloriesKcal()).thenReturn(new BigDecimal("200"));
        when(snapshot.getProteinGrams()).thenReturn(new BigDecimal("30"));when(snapshot.getCarbohydratesGrams()).thenReturn(BigDecimal.TEN);
        when(snapshot.getFatGrams()).thenReturn(BigDecimal.ONE);
        when(nutrition.findSnapshots(eq(UsdaFoodClient.PROVIDER),any())).thenReturn(List.of(snapshot));
        assertEquals(List.of(2L,1L),ids(home()));
        trusted.getIngredients().getFirst().setUnit("cup");assertEquals(List.of(1L,2L),ids(home()));
    }
    @Test void persistedCategoryPreferenceRanksButDoesNotOverrideEligibility() {
        recipe(1,"Alpha");var b=recipe(2,"Z soup");b.setCategory("Soup");
        profile.setPreferredCategories(Set.of("soup"));assertEquals(List.of(2L,1L),ids(home()));
        profile.setDislikedIngredientRefs(Set.of(b.getIngredients().getFirst().getIngredient()));
        assertEquals(List.of(1L),ids(home()));
    }
    @Test void privateRecipesAreScopedToCurrentUserAndPreferenceProfilesAreIsolated() {
        var own=recipe(1,"Owner private");own.setVisibility(RecipeVisibility.PRIVATE);
        var theirs=recipe(2,"Other private");theirs.setUser(other);theirs.setVisibility(RecipeVisibility.PRIVATE);
        recipe(3,"Public");profile.setDislikedIngredientRefs(Set.of(own.getIngredients().getFirst().getIngredient()));
        assertEquals(List.of(3L),ids(home()));
        assertEquals(List.of(2L,3L),ids(service.recommendHome(other.getEmail(),null,null,null)));
        verify(recipes,atLeastOnce()).findByUserOrVisibilityOrderByCreatedAtDesc(owner,RecipeVisibility.PUBLIC);
        verify(recipes).findByUserOrVisibilityOrderByCreatedAtDesc(other,RecipeVisibility.PUBLIC);
    }
    @Test void preferenceWritesAreReadOnNextRequestWithoutRestartOrRecipeWrites() {
        var a=recipe(1,"A");recipe(2,"B");assertEquals(List.of(1L,2L),ids(home()));
        when(ingredients.findAllById(Set.of(1L))).thenReturn(List.of(a.getIngredients().getFirst().getIngredient()));
        var request=new PreferencesRequest();request.setDislikedIngredientIds(Set.of(1L));
        preferences.updateUserPreferences(request,owner.getEmail());assertEquals(List.of(2L),ids(home()));
        verify(preferenceRows).save(profile);verify(recipes,never()).save(any());verify(pantry,never()).saveAndFlush(any());
    }
    @Test void unresolvedLegacyRestrictionsAreWithheldInsteadOfTreatedAsNoPreferences() {
        recipe(1,"Meal");profile.setAllergies(Set.of("unknown old allergen"));
        assertTrue(home().preferencesConfigured());assertTrue(home().selection().recommendations().isEmpty());
        assertTrue(home().limitations().stream().anyMatch(s->s.contains("Older food settings")));
    }
}
