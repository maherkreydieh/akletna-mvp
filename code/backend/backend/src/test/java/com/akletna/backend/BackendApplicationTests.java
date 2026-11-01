package com.akletna.backend;

import com.akletna.backend.config.*;
import com.akletna.backend.controller.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.exception.GlobalExceptionHandler;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.*;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Encoders;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.context.annotation.*;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockServletContext;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.FilterChainProxy;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.support.AnnotationConfigWebApplicationContext;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;

import javax.crypto.SecretKey;
import java.util.*;
import java.util.stream.Stream;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Actual filter chain/controllers/services; no development database or credentials. */
class BackendApplicationTests {
    private PantryItem pantryItem() {
        var item=new PantryItem();item.setId(41L);item.setUser(owner);item.setIngredient(ingredients.findById(7L).orElseThrow());
        item.setUpdatedAt(java.time.Instant.parse("2026-10-04T00:00:00Z"));
        return item;
    }
    private PantryItemRepository pantry() { return context.getBean(PantryItemRepository.class); }
    private void pantrySaveStub() {
        when(pantry().saveAndFlush(any())).thenAnswer(call->{PantryItem item=call.getArgument(0);if (item.getId()==null)item.setId(41L);return item;});
    }
    @Test void pantryKnownAndPresenceOnlyUseJwtIdentityAndDecimalCanonicalStorage() throws Exception {
        pantrySaveStub();
        mvc.perform(post("/api/pantry").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON)
                .content("{\"ingredientId\":7,\"quantity\":\"1.5\",\"unit\":\" KG \",\"userId\":2}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.quantity").value("1500"))
                .andExpect(jsonPath("$.unit").value("g")).andExpect(jsonPath("$.displayQuantity").value("1.5"))
                .andExpect(jsonPath("$.displayUnit").value("kg")).andExpect(jsonPath("$.userId").doesNotExist());
        mvc.perform(post("/api/pantry").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON)
                .content("{\"ingredientId\":7}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.quantity").isEmpty()).andExpect(jsonPath("$.unit").isEmpty());
        var captured=org.mockito.ArgumentCaptor.forClass(PantryItem.class);verify(pantry(),times(2)).saveAndFlush(captured.capture());
        org.junit.jupiter.api.Assertions.assertSame(owner,captured.getAllValues().getFirst().getUser());
        org.junit.jupiter.api.Assertions.assertNull(captured.getAllValues().getLast().getQuantity());
        verify(recipes,never()).save(any());verify(lines,never()).save(any());verify(ingredients,never()).save(any());
        verifyNoInteractions(context.getBean(MealPlanRepository.class),context.getBean(SavedRecipeRepository.class),context.getBean(com.akletna.backend.nutrition.UsdaFoodClient.class));
    }
    @Test void pantryUpdatesBothDirectionsAndExactDecimalsWithoutChangingIngredient() throws Exception {
        var item=pantryItem();when(pantry().findForUserById(1L,41L)).thenReturn(Optional.of(item));pantrySaveStub();
        for (String[] pair:new String[][]{{"0.75","l","750","mL"},{"3","piece","3","piece"},{"1.123456789012","clove","1.123456789012","clove"},{"999999999999.123456789012","g","999999999999.123456789012","g"}}) {
            mvc.perform(put("/api/pantry/41").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"quantity\":\""+pair[0]+"\",\"unit\":\""+pair[1]+"\",\"ingredientId\":999,\"userId\":2}"))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.quantity").value(pair[2])).andExpect(jsonPath("$.unit").value(pair[3]))
                    .andExpect(jsonPath("$.ingredientId").value(7));
        }
        mvc.perform(put("/api/pantry/41").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.quantity").isEmpty()).andExpect(jsonPath("$.unit").isEmpty()).andExpect(jsonPath("$.displayQuantity").isEmpty());
        mvc.perform(put("/api/pantry/41").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content("{\"quantity\":500,\"unit\":\"g\"}"))
                .andExpect(jsonPath("$.quantity").value("500"));
        org.junit.jupiter.api.Assertions.assertEquals(7L,item.getIngredient().getId());
    }
    @Test void pantryRejectsInconsistentNonpositiveMalformedAndOverflowAmounts() throws Exception {
        var item=pantryItem();when(pantry().findForUserById(1L,41L)).thenReturn(Optional.of(item));
        for (String fields:List.of("\"quantity\":1","\"unit\":\"g\"","\"quantity\":null,\"unit\":\"g\"",
                "\"quantity\":1,\"unit\":\" \"","\"quantity\":0,\"unit\":\"g\"","\"quantity\":-1,\"unit\":\"g\"",
                "\"quantity\":\"bad\",\"unit\":\"g\"","\"quantity\":true,\"unit\":\"g\"","\"quantity\":1e100,\"unit\":\"g\"",
                "\"quantity\":0.0000000000001,\"unit\":\"g\"","\"quantity\":999999999999999,\"unit\":\"kg\"")) {
            mvc.perform(post("/api/pantry").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,"+fields+"}"))
                    .andExpect(status().isBadRequest());
            mvc.perform(put("/api/pantry/41").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content("{"+fields+"}"))
                    .andExpect(status().isBadRequest());
        }
        verify(pantry(),never()).saveAndFlush(any());
    }
    @Test void pantryDuplicatesConflictButEachUserCanHaveSameIngredient() throws Exception {
        pantrySaveStub();when(pantry().existsByUserIdAndIngredientId(1L,7L)).thenReturn(true);
        String body="{\"ingredientId\":7}";
        mvc.perform(post("/api/pantry").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.message").value(containsString("Edit the existing item")));
        mvc.perform(post("/api/pantry").header("Authorization","Bearer "+otherToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isCreated());
        verify(pantry(),times(1)).saveAndFlush(any());
    }
    @Test void pantryReadsDeletesAndMutationsRemainPrivateAndAuthenticated() throws Exception {
        var item=pantryItem();when(pantry().findForUserById(1L,41L)).thenReturn(Optional.of(item));
        when(pantry().findForUser(1L)).thenReturn(List.of(item));when(pantry().findForUser(2L)).thenReturn(List.of());
        mvc.perform(get("/api/pantry?userId=2").header("Authorization","Bearer "+ownerToken)).andExpect(jsonPath("$[0].id").value(41));
        mvc.perform(get("/api/pantry?userId=1").header("Authorization","Bearer "+otherToken)).andExpect(jsonPath("$").isEmpty());
        mvc.perform(get("/api/pantry/41").header("Authorization","Bearer "+otherToken)).andExpect(status().isNotFound());
        mvc.perform(put("/api/pantry/41").header("Authorization","Bearer "+otherToken).contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/pantry/41").header("Authorization","Bearer "+otherToken)).andExpect(status().isNotFound());
        mvc.perform(get("/api/pantry")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/pantry/41")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/pantry").contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7}")).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/pantry/41").contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/pantry/41")).andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/pantry/41").header("Authorization","Bearer "+ownerToken)).andExpect(status().isNoContent());
        verify(pantry()).delete(item);verify(ingredients,never()).delete(any());verify(recipes,never()).save(any());
    }
    @Test void normalizesUnitsAcrossIngredientAndRecipeCreateEditContracts() throws Exception {
        mvc.perform(post("/api/ingredients").header("Authorization","Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Milk\",\"unit\":\" ML \"}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.unit").value("mL"));
        String body = "{\"name\":\"Unit recipe\",\"instructions\":\"Test\",\"servings\":2,\"ingredients\":[{\"ingredientId\":7,\"quantity\":0.5,\"unit\":\" KG \"}]}";
        mvc.perform(post("/api/recipes").header("Authorization","Bearer " + ownerToken).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated());
        var captured = org.mockito.ArgumentCaptor.forClass(Recipe.class);
        verify(recipes).save(captured.capture());
        org.junit.jupiter.api.Assertions.assertEquals("kg",captured.getValue().getIngredients().getFirst().getUnit());
        mvc.perform(put("/api/recipes/11").header("Authorization","Bearer " + ownerToken).contentType(MediaType.APPLICATION_JSON).content(body.replace(" KG ","ml")))
                .andExpect(status().isOk());
        org.junit.jupiter.api.Assertions.assertEquals("mL",recipe.getIngredients().getFirst().getUnit());
        mvc.perform(put("/api/recipes/11/ingredients/21").header("Authorization","Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":1,\"unit\":\" l \"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.unit").value("L"));
        mvc.perform(post("/api/recipes/11/ingredients").header("Authorization","Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":1,\"unit\":\" clove \"}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.unit").value("clove"));
    }
    private static final SecretKey TEST_KEY = Jwts.SIG.HS256.key().build();
    private AnnotationConfigWebApplicationContext context;
    private MockMvc mvc;
    private UserRepository users;
    private RecipeRepository recipes;
    private IngredientRepository ingredients;
    private RecipeIngredientRepository lines;
    private User owner;
    private User other;
    private Recipe recipe;
    private String ownerToken;
    private String otherToken;

    @BeforeEach
    void setUp() {
        context = new AnnotationConfigWebApplicationContext();
        context.setServletContext(new MockServletContext());
        context.register(IsolatedConfiguration.class);
        context.refresh();
        mvc = MockMvcBuilders.webAppContextSetup(context)
                .addFilters(context.getBean(FilterChainProxy.class)).build();
        users = context.getBean(UserRepository.class);
        recipes = context.getBean(RecipeRepository.class);
        ingredients = context.getBean(IngredientRepository.class);
        lines = context.getBean(RecipeIngredientRepository.class);

        owner = user(1L, "owner@example.test");
        other = user(2L, "other@example.test");
        owner.setPassword(context.getBean(PasswordEncoder.class).encode("test-password"));
        when(users.findByEmail(owner.getEmail())).thenReturn(Optional.of(owner));
        when(users.findByEmail(other.getEmail())).thenReturn(Optional.of(other));
        when(users.findLockedById(1L)).thenReturn(Optional.of(owner));
        when(users.findLockedById(2L)).thenReturn(Optional.of(other));
        recipe = new Recipe();
        recipe.setId(11L);
        recipe.setName("Lentil soup");
        recipe.setServings(4);
        recipe.setInstructions("Cook the lentils.");
        recipe.setUser(owner);
        when(recipes.findById(11L)).thenReturn(Optional.of(recipe));
        when(recipes.findLockedById(anyLong())).thenAnswer(i -> recipes.findById(i.getArgument(0)));
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(owner, RecipeVisibility.PUBLIC)).thenReturn(List.of(recipe));
        when(recipes.save(any())).thenAnswer(invocation -> {
            Recipe saved = invocation.getArgument(0);
            if (saved.getId() == null) saved.setId(12L);
            return saved;
        });
        Ingredient ingredient = new Ingredient();
        ingredient.setId(7L);
        ingredient.setName("Lentils");
        ingredient.setUnit("cup");
        when(ingredients.findById(7L)).thenReturn(Optional.of(ingredient));
        when(ingredients.findAll()).thenReturn(List.of(ingredient));
        RecipeIngredient line = new RecipeIngredient();
        line.setId(21L); line.setUnit("cup");
        line.setRecipe(recipe);
        line.setIngredient(ingredient);
        line.setQuantity(new java.math.BigDecimal("1.5"));
        when(lines.findByRecipeId(11L)).thenReturn(List.of(line));
        when(lines.findByIdAndRecipeId(21L, 11L)).thenReturn(Optional.of(line));
        when(lines.save(any())).thenAnswer(invocation -> {
            RecipeIngredient saved = invocation.getArgument(0);
            if (saved.getId() == null) saved.setId(22L);
            return saved;
        });
        when(ingredients.save(any())).thenAnswer(invocation -> {
            Ingredient saved = invocation.getArgument(0);
            saved.setId(8L);
            return saved;
        });
        JwtService jwt = context.getBean(JwtService.class);
        ownerToken = jwt.generateToken(owner);
        otherToken = jwt.generateToken(other);
    }

    @Test void homeRecommendationsRequireJwtIgnoreClientIdentityAndRecheckSavedPreferences() throws Exception {
        var ingredient=ingredients.findById(7L).orElseThrow();
        var line=new RecipeIngredient();line.setIngredient(ingredient);line.setQuantity(java.math.BigDecimal.ONE);line.setUnit("g");
        recipe.getIngredients().add(line);
        var profile=new UserPreference(owner);profile.setAllergies(Set.of("SESAME"));
        when(context.getBean(UserPreferenceRepository.class).findByUser(owner)).thenReturn(Optional.of(profile));
        var classification=new IngredientClassification();classification.setIngredient(ingredient);
        classification.setAllergens(Set.of(Allergen.SESAME));classification.setAllergensComplete(true);
        when(context.getBean(IngredientClassificationRepository.class).findForIngredients(any())).thenReturn(List.of(classification));
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(other,RecipeVisibility.PUBLIC)).thenReturn(List.of());
        mvc.perform(get("/api/recipes/recommendations/home")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/recipes/recommendations/home?userId=2").header("Authorization","Bearer "+ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.preferencesConfigured").value(true))
                .andExpect(jsonPath("$.selection.recommendations").isEmpty())
                .andExpect(jsonPath("$.selection.excludedRecipeCount").value(1));
        profile.setAllergies(Set.of());
        mvc.perform(get("/api/recipes/recommendations/home").header("Authorization","Bearer "+ownerToken))
                .andExpect(jsonPath("$.preferencesConfigured").value(false))
                .andExpect(jsonPath("$.selection.recommendations[0].recipe.id").value(11));
        mvc.perform(get("/api/recipes/recommendations/home?userId=1").header("Authorization","Bearer "+otherToken))
                .andExpect(jsonPath("$.selection.recommendations").isEmpty());
        verify(recipes,never()).save(any());verify(context.getBean(UserPreferenceRepository.class),never()).save(any());
        verifyNoInteractions(context.getBean(com.akletna.backend.nutrition.UsdaFoodClient.class));
    }
    @Test void recommendationsRequireJwtUseCurrentUserAndPreserveStoredSignals() throws Exception {
        var line=new RecipeIngredient();line.setIngredient(ingredients.findById(7L).orElseThrow());
        line.setQuantity(new java.math.BigDecimal("500"));line.setUnit("g");recipe.getIngredients().add(line);
        var p=pantryItem();p.setQuantity(new java.math.BigDecimal("1000"));p.setUnit("g");
        when(pantry().findForUser(1L)).thenReturn(List.of(p));
        when(context.getBean(SavedRecipeRepository.class).savedIdsForUser(eq(1L),anyList())).thenReturn(List.of(11L));
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(other,RecipeVisibility.PUBLIC)).thenReturn(List.of());
        mvc.perform(get("/api/recipes/recommendations")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/recipes/recommendations?userId=2").header("Authorization","Bearer "+ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.recommendations[0].rank").value(1))
                .andExpect(jsonPath("$.recommendations[0].score").value(55))
                .andExpect(jsonPath("$.recommendations[0].pantryPercentage").value(100))
                .andExpect(jsonPath("$.recommendations[0].recipe.saved").value(true))
                .andExpect(jsonPath("$.preferences").doesNotExist());
        mvc.perform(get("/api/recipes/recommendations").header("Authorization","Bearer "+otherToken))
                .andExpect(jsonPath("$.pantryEmpty").value(true)).andExpect(jsonPath("$.recommendations").isEmpty());
        mvc.perform(get("/api/recipes/recommendations?goal=HIGH_PROTEIN").header("Authorization","Bearer "+ownerToken))
                .andExpect(jsonPath("$.recommendations").isEmpty());
        mvc.perform(get("/api/recipes/recommendations?diet=INVALID").header("Authorization","Bearer "+ownerToken)).andExpect(status().isBadRequest());
        verify(pantry(),never()).saveAndFlush(any());verify(recipes,never()).save(any());verify(lines,never()).save(any());
        verify(context.getBean(UserPreferenceRepository.class),never()).save(any());
        verify(context.getBean(SavedRecipeRepository.class),never()).save(any());
        verifyNoInteractions(context.getBean(com.akletna.backend.nutrition.UsdaFoodClient.class));
    }
    @Test void recommendationTiesUseCaseInsensitiveNameThenIdAndCategoryFilterPreservesRanks() throws Exception {
        var ingredient=ingredients.findById(7L).orElseThrow();
        var firstLine=new RecipeIngredient();firstLine.setIngredient(ingredient);firstLine.setQuantity(java.math.BigDecimal.ONE);firstLine.setUnit("g");
        recipe.setName("alpha");recipe.setCategory("Yakhnet");recipe.getIngredients().add(firstLine);
        var second=new Recipe();second.setId(12L);second.setName("ALPHA");second.setUser(owner);second.setServings(1);second.setCategory("Salads");
        var secondLine=new RecipeIngredient();secondLine.setIngredient(ingredient);secondLine.setQuantity(java.math.BigDecimal.ONE);secondLine.setUnit("g");second.getIngredients().add(secondLine);
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(owner,RecipeVisibility.PUBLIC)).thenReturn(List.of(second,recipe));
        mvc.perform(get("/api/recipes/recommendations").header("Authorization","Bearer "+ownerToken))
                .andExpect(jsonPath("$.recommendations[0].recipe.id").value(11)).andExpect(jsonPath("$.recommendations[1].recipe.id").value(12))
                .andExpect(jsonPath("$.recommendations[0].pantryPercentage").isEmpty()).andExpect(jsonPath("$.recommendations[1].rank").value(2));
        mvc.perform(get("/api/recipes/recommendations?category=Salads").header("Authorization","Bearer "+ownerToken))
                .andExpect(jsonPath("$.recommendations.length()").value(1)).andExpect(jsonPath("$.recommendations[0].recipe.id").value(12))
                .andExpect(jsonPath("$.recommendations[0].rank").value(1));
    }
    @Test void pantryMatchingUsesAuthenticatedReadableScopeWithoutWritesOrNutrition() throws Exception {
        var line=new RecipeIngredient();line.setIngredient(ingredients.findById(7L).orElseThrow());
        line.setQuantity(new java.math.BigDecimal("500"));line.setUnit("g");recipe.getIngredients().add(line);
        var p=pantryItem();p.setQuantity(new java.math.BigDecimal("1000"));p.setUnit("g");
        when(pantry().findForUser(1L)).thenReturn(List.of(p));
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(other,RecipeVisibility.PUBLIC)).thenReturn(List.of());
        mvc.perform(get("/api/recipes/pantry-matches")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/recipes/pantry-matches?userId=2").header("Authorization","Bearer "+ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.pantryEmpty").value(false))
                .andExpect(jsonPath("$.matches[0].id").value(11)).andExpect(jsonPath("$.matches[0].status").value("READY_TO_COOK"))
                .andExpect(jsonPath("$.matches[0].score").value(100)).andExpect(jsonPath("$.matches[0].ingredients[0].available.quantity").value("1000"));
        mvc.perform(get("/api/recipes/pantry-matches?userId=1").header("Authorization","Bearer "+otherToken))
                .andExpect(jsonPath("$.pantryEmpty").value(true)).andExpect(jsonPath("$.readableRecipeCount").value(0))
                .andExpect(jsonPath("$.matches").isEmpty());
        verify(pantry(),never()).save(any());verify(pantry(),never()).delete(any());
        verify(recipes,never()).save(any());verify(lines,never()).save(any());
        verifyNoInteractions(context.getBean(MealPlanRepository.class),context.getBean(SavedRecipeRepository.class),
                context.getBean(com.akletna.backend.nutrition.UsdaFoodClient.class));
    }

    @Test void preferencesAreJwtPrivateAndDislikesAndGoalsUseValidatedStructuredValues() throws Exception {
        var prefs=context.getBean(UserPreferenceRepository.class);var profile=new UserPreference(owner);
        when(prefs.findByUser(owner)).thenReturn(Optional.of(profile));when(prefs.save(any())).thenAnswer(i->i.getArgument(0));
        var ingredient=ingredients.findById(7L).orElseThrow();when(ingredients.findAllById(Set.of(7L))).thenReturn(List.of(ingredient));
        mvc.perform(get("/api/preferences")).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/preferences").contentType(MediaType.APPLICATION_JSON).content("{}")) .andExpect(status().isUnauthorized());
        mvc.perform(put("/api/preferences").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON)
                .content("{\"userId\":2,\"dietaryRestrictions\":[\"VEGAN\"],\"allergies\":[\"SESAME\"],\"dislikedIngredientIds\":[7],\"preferredMealGoals\":[\"HIGH_PROTEIN\",\"BUDGET_FRIENDLY\"]}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.allergies[0]").value("SESAME"))
                .andExpect(jsonPath("$.dislikedIngredientIds[0]").value(7)).andExpect(jsonPath("$.preferredMealGoals.length()").value(2));
        mvc.perform(get("/api/preferences?userId=1").header("Authorization","Bearer "+otherToken)).andExpect(jsonPath("$.allergies").isEmpty());
        for(String invalid:List.of("{\"allergies\":[\"made up\"]}","{\"dietaryRestrictions\":[\"invalid\"]}","{\"dislikedIngredientIds\":[999]}","{\"dislikedIngredientIds\":[-1]}","{\"preferredMealGoals\":[\"invalid\"]}"))
            mvc.perform(put("/api/preferences").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content(invalid)).andExpect(status().isBadRequest());
        assertEquals(Set.of("SESAME"),profile.getAllergies());assertSame(owner,profile.getUser());
        verify(recipes,never()).save(any());verify(pantry(),never()).save(any());verifyNoInteractions(context.getBean(MealPlanRepository.class),context.getBean(SavedRecipeRepository.class));
    }

    @Test void trustedFoodMetadataRequiresJwtCuratorReviewAndCuratedBudgetOrigin() throws Exception {
        String classification="{\"allergens\":[\"SESAME\"],\"allergensComplete\":true,\"vegetarian\":\"COMPATIBLE\",\"vegan\":\"COMPATIBLE\",\"reviewed\":true}";
        mvc.perform(put("/api/food-metadata/curation/ingredients/7").contentType(MediaType.APPLICATION_JSON).content(classification)
                .header("X-Nutrition-Curator-Token","test-curator-token-".repeat(3))).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/food-metadata/curation/ingredients/7").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content(classification)).andExpect(status().isForbidden());
        mvc.perform(put("/api/food-metadata/curation/recipes/11").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content("{\"budgetFriendly\":true,\"reviewed\":true}")) .andExpect(status().isForbidden());
        mvc.perform(put("/api/food-metadata/curation/ingredients/7").header("Authorization","Bearer "+ownerToken).header("X-Nutrition-Curator-Token","wrong").contentType(MediaType.APPLICATION_JSON).content(classification)).andExpect(status().isForbidden());
        mvc.perform(put("/api/food-metadata/curation/ingredients/7").header("Authorization","Bearer "+ownerToken).header("X-Nutrition-Curator-Token","test-curator-token-".repeat(3)).contentType(MediaType.APPLICATION_JSON).content(classification)).andExpect(status().isOk());
        var capture=org.mockito.ArgumentCaptor.forClass(IngredientClassification.class);verify(context.getBean(IngredientClassificationRepository.class)).save(capture.capture());assertEquals(Set.of(Allergen.SESAME),capture.getValue().getAllergens());
        mvc.perform(put("/api/food-metadata/curation/recipes/11").header("Authorization","Bearer "+ownerToken).header("X-Nutrition-Curator-Token","test-curator-token-".repeat(3)).contentType(MediaType.APPLICATION_JSON).content("{\"budgetFriendly\":true,\"reviewed\":true}")) .andExpect(status().isBadRequest());
        recipe.setOrigin(RecipeOrigin.CURATED);
        mvc.perform(put("/api/food-metadata/curation/recipes/11").header("Authorization","Bearer "+ownerToken).header("X-Nutrition-Curator-Token","test-curator-token-".repeat(3)).contentType(MediaType.APPLICATION_JSON).content("{\"budgetFriendly\":true,\"reviewed\":true}")) .andExpect(status().isOk());
        verify(context.getBean(RecipeClassificationRepository.class)).save(any());verify(ingredients,never()).save(any());
    }

    @Test void discoveryCombinesCategoryDietAndTrustedGoalsAndPreservesPantryScore() throws Exception {
        var ingredient=ingredients.findById(7L).orElseThrow();var line=new RecipeIngredient();line.setIngredient(ingredient);line.setQuantity(new java.math.BigDecimal("500"));line.setUnit("g");recipe.getIngredients().add(line);
        recipe.setOrigin(RecipeOrigin.CURATED);recipe.setVisibility(RecipeVisibility.PUBLIC);recipe.setCategory("Yakhnet");
        when(recipes.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.CURATED,RecipeVisibility.PUBLIC)).thenReturn(List.of(recipe));
        var classification=new IngredientClassification();classification.setIngredient(ingredient);classification.setAllergens(Set.of(Allergen.SESAME));classification.setAllergensComplete(true);classification.setVegetarian(CompatibilityStatus.COMPATIBLE);classification.setVegan(CompatibilityStatus.COMPATIBLE);
        when(context.getBean(IngredientClassificationRepository.class).findForIngredients(any())).thenReturn(List.of(classification));
        var budget=new RecipeClassification();budget.setRecipe(recipe);budget.setBudgetFriendly(true);when(context.getBean(RecipeClassificationRepository.class).findAllById(any())).thenReturn(List.of(budget));
        mvc.perform(get("/api/recipes?category=Yakhnet&goal=BUDGET_FRIENDLY&diet=VEGETARIAN").header("Authorization","Bearer "+ownerToken)).andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(11));
        mvc.perform(get("/api/recipes?category=Mezze&goal=BUDGET_FRIENDLY").header("Authorization","Bearer "+ownerToken)).andExpect(jsonPath("$").isEmpty());
        mvc.perform(get("/api/recipes?goal=HIGH_PROTEIN").header("Authorization","Bearer "+ownerToken)).andExpect(jsonPath("$").isEmpty());
        mvc.perform(get("/api/recipes?diet=madeup").header("Authorization","Bearer "+ownerToken)).andExpect(status().isBadRequest());
        var item=pantryItem();item.setQuantity(new java.math.BigDecimal("500"));item.setUnit("g");when(pantry().findForUser(1L)).thenReturn(List.of(item));
        mvc.perform(get("/api/recipes/pantry-matches").header("Authorization","Bearer "+ownerToken)).andExpect(jsonPath("$.matches[0].score").value(100));
        var profile=new UserPreference(owner);profile.setAllergies(Set.of("SESAME"));when(context.getBean(UserPreferenceRepository.class).findByUser(owner)).thenReturn(Optional.of(profile));
        mvc.perform(get("/api/recipes/pantry-matches").header("Authorization","Bearer "+ownerToken)).andExpect(jsonPath("$.matches[0].score").value(100)).andExpect(jsonPath("$.matches[0].status").value("READY_TO_COOK"))
                .andExpect(jsonPath("$.matches[0].evaluation.compatibility").value("CONFLICT")).andExpect(jsonPath("$.matches[0].evaluation.reasons[0].message").value("Contains sesame"));
        verifyNoInteractions(context.getBean(com.akletna.backend.nutrition.UsdaFoodClient.class),context.getBean(MealPlanRepository.class));verify(pantry(),never()).save(any());
    }

    @AfterEach
    void closeContext() { context.close(); }

    @Test
    void protectedEndpointsRequireAuthentication() throws Exception {
        mvc.perform(get("/api/recipes/11/ingredients"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Authentication is required. Please sign in again."));
        verifyNoInteractions(recipes, lines, ingredients);
    }

    static Stream<String> invalidTokens() {
        Date past = new Date(System.currentTimeMillis() - 60000);
        Date future = new Date(System.currentTimeMillis() + 60000);
        return Stream.of("", "garbage", "one.two.three",
                Jwts.builder().claim("userId", 1L).subject("owner@example.test").expiration(past).signWith(TEST_KEY).compact(),
                Jwts.builder().claim("userId", 1L).subject("owner@example.test").expiration(future)
                        .signWith(Jwts.SIG.HS256.key().build()).compact(),
                Jwts.builder().claim("userId", 1L).expiration(future).signWith(TEST_KEY).compact(),
                Jwts.builder().claim("userId", 1L).subject(" ").expiration(future).signWith(TEST_KEY).compact(),
                Jwts.builder().claim("userId", 1L).subject("owner@example.test").signWith(TEST_KEY).compact(),
                Jwts.builder().claim("userId", 1L).subject("owner@example.test").notBefore(future)
                        .expiration(new Date(future.getTime() + 60000)).signWith(TEST_KEY).compact(),
                Jwts.builder().claim("userId", 1L).subject("owner@example.test").expiration(future).compact());
    }

    @ParameterizedTest(name = "invalid JWT case {index}")
    @MethodSource("invalidTokens")
    void invalidJwtProducesGeneric401(String token) throws Exception {
        mvc.perform(get("/api/recipes/11/ingredients").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.message").value("Authentication is required. Please sign in again."))
                .andExpect(content().string(not(containsString("signature"))))
                .andExpect(content().string(not(containsString("expired"))));
        verifyNoInteractions(recipes, lines, ingredients);
    }

    @Test
    void loginStillReturnsValidJwtAndProfile() throws Exception {
        String body = mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"owner@example.test\",\"password\":\"test-password\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.name").value("Test User"))
                .andReturn().getResponse().getContentAsString();
        String token = tools.jackson.databind.json.JsonMapper.builder().build()
                .readTree(body).get("token").asString();
        mvc.perform(get("/api/users/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.password").doesNotExist());
    }

    @Test void invalidJwtConfigurationFailsAtConstruction() {
        org.junit.jupiter.api.Assertions.assertThrows(RuntimeException.class,
                () -> new JwtService("", 1000));
        org.junit.jupiter.api.Assertions.assertThrows(RuntimeException.class,
                () -> new JwtService("invalid-base64!", 1000));
        org.junit.jupiter.api.Assertions.assertThrows(RuntimeException.class,
                () -> new JwtService(Encoders.BASE64.encode(new byte[16]), 1000));
        org.junit.jupiter.api.Assertions.assertThrows(IllegalArgumentException.class,
                () -> new JwtService(Encoders.BASE64.encode(TEST_KEY.getEncoded()), 0));
    }

    @Test void deletedAccountAndReusedEmailCannotUseOldTokenOnSharedEndpoints() throws Exception {
        when(users.findByEmail(owner.getEmail())).thenReturn(Optional.empty());
        mvc.perform(get("/api/ingredients").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isUnauthorized());
        when(users.findByEmail(owner.getEmail())).thenReturn(Optional.of(user(99L, owner.getEmail())));
        mvc.perform(get("/api/ingredients").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isUnauthorized());
        verify(ingredients, never()).findAll();
    }

    @Test void signedTokenRequiresAnIntegralPositiveAccountId() throws Exception {
        for (Object id : Arrays.asList(null, -1, 0, "1", 1.5)) {
            String token = Jwts.builder().subject(owner.getEmail()).claim("userId", id)
                    .expiration(new Date(System.currentTimeMillis() + 60000)).signWith(TEST_KEY).compact();
            mvc.perform(get("/api/ingredients").header("Authorization", "Bearer " + token))
                    .andExpect(status().isUnauthorized());
        }
    }

    @Test void recipeIntegersIdsAndEnumsRejectSilentCoercion() throws Exception {
        for (String value : List.of("2.5", "2.0", "\"2\"", "true", "2147483648")) {
            mvc.perform(post("/api/recipes").header("Authorization", "Bearer " + ownerToken)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"name\":\"Test recipe\",\"instructions\":\"Cook\",\"servings\":"+value+"}"))
                    .andExpect(status().isBadRequest());
        }
        for (String value : List.of("7.5", "7.0", "\"7\"", "-1", "0")) {
            mvc.perform(post("/api/recipes/11/ingredients").header("Authorization", "Bearer " + ownerToken)
                    .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":"+value+",\"quantity\":1}"))
                    .andExpect(status().isBadRequest());
        }
        mvc.perform(post("/api/recipes").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Test recipe\",\"instructions\":\"Cook\",\"servings\":2,\"visibility\":0}"))
                .andExpect(status().isBadRequest());
        verify(recipes,never()).save(any()); verify(lines,never()).save(any());
    }

    @Test void passwordsBeyondBcryptByteLimitProduceSafeValidationErrors() throws Exception {
        for (String password : List.of("a".repeat(73), "é".repeat(37))) {
            String body = "{\"email\":\"owner@example.test\",\"name\":\"Test User\",\"password\":\"" + password + "\"}";
            for (String action : List.of("login", "register")) {
                mvc.perform(post("/api/auth/" + action).contentType(MediaType.APPLICATION_JSON).content(body))
                        .andExpect(status().isBadRequest()).andExpect(content().string(not(containsString(password))));
            }
        }
        verify(users, never()).saveAndFlush(any());
    }

    @Test void unsupportedMethodAndContentTypeAreControlledClientErrors() throws Exception {
        mvc.perform(patch("/api/recipes/11").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isMethodNotAllowed());
        mvc.perform(post("/api/auth/login").contentType(MediaType.TEXT_PLAIN).content("invalid"))
                .andExpect(status().isUnsupportedMediaType());
    }

    @Test
    void recipeMetadataAndIngredientContractRemainSeparate() throws Exception {
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.name").value("Lentil soup"))
                .andExpect(jsonPath("$.ingredients").doesNotExist());
        mvc.perform(get("/api/recipes/11/ingredients").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(21))
                .andExpect(jsonPath("$[0].recipeId").value(11))
                .andExpect(jsonPath("$[0].ingredientId").value(7))
                .andExpect(jsonPath("$[0].ingredientName").value("Lentils"))
                .andExpect(jsonPath("$[0].unit").value("cup"))
                .andExpect(jsonPath("$[0].quantity").value(1.5));
    }

    @Test
    void plannerAvailableIsScopedToCurrentUser() throws Exception {
        mvc.perform(get("/api/recipes/available").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(11));
        mvc.perform(get("/api/recipes/available").header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void anotherUserCannotReadOrMutateRecipeLines() throws Exception {
        String authorization = "Bearer " + otherToken;
        mvc.perform(get("/api/recipes/11").header("Authorization", authorization))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/recipes/11/ingredients").header("Authorization", authorization))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/recipes/11/ingredients").header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":2}"))
                .andExpect(status().isNotFound());
        mvc.perform(put("/api/recipes/11/ingredients/21").header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":2}"))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/recipes/11/ingredients/21").header("Authorization", authorization))
                .andExpect(status().isNotFound());
        verifyNoInteractions(lines);
        verify(ingredients, never()).save(any());
    }

    @Test
    void recipeOwnerCanAddUpdateAndRemoveTheirLines() throws Exception {
        String authorization = "Bearer " + ownerToken;
        mvc.perform(post("/api/recipes/11/ingredients").header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":2}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.ingredientName").value("Lentils"));
        mvc.perform(put("/api/recipes/11/ingredients/21").header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":3}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.quantity").value(3.0));
        mvc.perform(delete("/api/recipes/11/ingredients/21").header("Authorization", authorization))
                .andExpect(status().isNoContent());
        verify(lines).delete(any(RecipeIngredient.class));
        verify(ingredients, never()).save(any());
    }

    @ParameterizedTest
    @ValueSource(strings = {"PUT", "PATCH", "DELETE"})
    void authenticatedUsersCannotChangeSharedIngredients(String method) throws Exception {
        mvc.perform(request(org.springframework.http.HttpMethod.valueOf(method), "/api/ingredients/7")
                        .header("Authorization", "Bearer " + otherToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Changed\",\"unit\":\"g\"}"))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.message").value("Access denied."));
        verifyNoInteractions(ingredients);
    }

    @Test
    void catalogReadAndNewIngredientCreationStillWork() throws Exception {
        String authorization = "Bearer " + ownerToken;
        mvc.perform(get("/api/ingredients").header("Authorization", authorization))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].name").value("Lentils"));
        mvc.perform(post("/api/ingredients").header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Rice\",\"unit\":\"cup\"}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.id").value(8));
        when(ingredients.existsByNameIgnoreCase("Lentils")).thenReturn(true);
        mvc.perform(post("/api/ingredients").header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Lentils\",\"unit\":\"g\"}"))
                .andExpect(status().isBadRequest());
        verify(ingredients, times(1)).save(any());
    }

    @Test
    void invalidQuantitiesNeverReachPersistence() throws Exception {
        mvc.perform(post("/api/recipes/11/ingredients").header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":0}"))
                .andExpect(status().isBadRequest());
        verify(lines, never()).save(any());
    }

    @Test
    void internalExceptionDetailsAreNotReturned() throws Exception {
        when(ingredients.findAll()).thenThrow(new IllegalStateException("private-database-details"));
        mvc.perform(get("/api/ingredients").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isInternalServerError())
                .andExpect(content().string(not(containsString("private-database-details"))));
    }

    @Test
    void creationForcesAuthenticatedOwnerAndUserOriginAndPersistsLines() throws Exception {
        mvc.perform(post("/api/recipes").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Soup\",\"instructions\":\"Cook\",\"servings\":2,\"visibility\":\"PUBLIC\",\"origin\":\"CURATED\",\"userId\":2,\"ingredients\":[{\"ingredientId\":7,\"quantity\":1.5}]}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.origin").value("USER"))
                .andExpect(jsonPath("$.visibility").value("PUBLIC"))
                .andExpect(jsonPath("$.userId").value(1));
        var capture = org.mockito.ArgumentCaptor.forClass(Recipe.class);
        verify(recipes).save(capture.capture());
        Assertions.assertEquals(1, capture.getValue().getIngredients().size());
        Assertions.assertEquals(7L, capture.getValue().getIngredients().getFirst().getIngredient().getId());
        Assertions.assertSame(capture.getValue(), capture.getValue().getIngredients().getFirst().getRecipe());
    }

    @Test
    void publicReadDoesNotGrantRecipeOrLineMutationRights() throws Exception {
        recipe.setVisibility(RecipeVisibility.PUBLIC);
        when(recipes.findByUserOrVisibilityOrderByCreatedAtDesc(other, RecipeVisibility.PUBLIC)).thenReturn(List.of(recipe));
        String auth = "Bearer " + otherToken;
        mvc.perform(get("/api/recipes/available").header("Authorization", auth)).andExpect(jsonPath("$[0].id").value(11));
        mvc.perform(get("/api/recipes/11").header("Authorization", auth)).andExpect(status().isOk());
        mvc.perform(get("/api/recipes/11/ingredients").header("Authorization", auth)).andExpect(status().isOk());
        mvc.perform(put("/api/recipes/11").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Changed\",\"instructions\":\"Cook\",\"servings\":2}")).andExpect(status().isForbidden());
        mvc.perform(delete("/api/recipes/11").header("Authorization", auth)).andExpect(status().isForbidden());
        mvc.perform(delete("/api/recipes/11/ingredients/21").header("Authorization", auth)).andExpect(status().isForbidden());
        verify(recipes, never()).save(any()); verify(recipes, never()).delete(any());
    }

    @Test
    void ownerCanUpdateVisibilityAndDeleteButCannotPromoteOrigin() throws Exception {
        String auth = "Bearer " + ownerToken;
        mvc.perform(put("/api/recipes/11").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Changed\",\"instructions\":\"Cook\",\"servings\":2,\"visibility\":\"PUBLIC\",\"origin\":\"CURATED\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.origin").value("USER"))
                .andExpect(jsonPath("$.visibility").value("PUBLIC"));
        mvc.perform(delete("/api/recipes/11").header("Authorization", auth)).andExpect(status().isNoContent());
        verify(recipes).delete(recipe);
    }

    @Test
    void curatedPublicRecipesRemainReadableAndImmutableEvenForRecordedCreator() throws Exception {
        recipe.setOrigin(RecipeOrigin.CURATED); recipe.setVisibility(RecipeVisibility.PUBLIC);
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.origin").value("CURATED"));
        for (String token : List.of(ownerToken, otherToken)) {
            mvc.perform(delete("/api/recipes/11").header("Authorization", "Bearer " + token)).andExpect(status().isForbidden());
            mvc.perform(put("/api/recipes/11").header("Authorization", "Bearer " + token).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"name\":\"Changed\",\"instructions\":\"Cook\",\"servings\":2}")).andExpect(status().isForbidden());
            mvc.perform(delete("/api/recipes/11/ingredients/21").header("Authorization", "Bearer " + token)).andExpect(status().isForbidden());
        }
        verify(recipes, never()).delete(any()); verify(lines, never()).delete(any());
    }

    @Test
    void invalidNestedCreationQuantitiesAndDuplicatesAreRejectedBeforeSave() throws Exception {
        for (String values : List.of("[{\"ingredientId\":7,\"quantity\":0}]", "[null]",
                "[{\"ingredientId\":7,\"quantity\":1},{\"ingredientId\":7,\"quantity\":2}]")) {
            mvc.perform(post("/api/recipes").header("Authorization", "Bearer " + ownerToken).contentType(MediaType.APPLICATION_JSON)
                    .content("{\"name\":\"Soup\",\"instructions\":\"Cook\",\"servings\":2,\"ingredients\":" + values + "}"))
                    .andExpect(status().isBadRequest());
        }
        verify(recipes, never()).save(any());
    }

    @Test
    void invalidVisibilityIsAValidationFailureWithoutParsingDetails() throws Exception {
        mvc.perform(post("/api/recipes").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Soup\",\"instructions\":\"Cook\",\"servings\":2,\"visibility\":\"INVALID\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Invalid request body. Check the submitted values."));
        verify(recipes, never()).save(any());
    }

    @Test
    void myRecipesUsesAuthenticatedOwnerIncludesBothVisibilitiesAndExcludesCurated() throws Exception {
        Recipe ownPublic = new Recipe(); ownPublic.setId(12L); ownPublic.setUser(owner);
        ownPublic.setName("Public soup"); ownPublic.setVisibility(RecipeVisibility.PUBLIC);
        Recipe curated = new Recipe(); curated.setId(13L); curated.setUser(owner); curated.setOrigin(RecipeOrigin.CURATED);
        when(recipes.findByUserOrderByCreatedAtDesc(owner)).thenReturn(List.of(recipe, ownPublic, curated));
        mvc.perform(get("/api/recipes/mine?userId=2").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].visibility").value("PRIVATE"))
                .andExpect(jsonPath("$[1].visibility").value("PUBLIC"));
        mvc.perform(get("/api/recipes/mine").header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get("/api/recipes/mine")).andExpect(status().isUnauthorized());
        verify(recipes).findByUserOrderByCreatedAtDesc(owner);
        verify(recipes).findByUserOrderByCreatedAtDesc(other);
    }

    @Test
    void ownerReplacesIngredientsAndCanRemoveAllWithoutChangingOriginOrCreator() throws Exception {
        RecipeIngredient old = new RecipeIngredient(); old.setId(21L); old.setRecipe(recipe);
        old.setIngredient(ingredients.findById(7L).orElseThrow()); old.setQuantity(new java.math.BigDecimal("1.5"));
        recipe.getIngredients().add(old);
        mvc.perform(put("/api/recipes/11").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Updated\",\"instructions\":\"Cook\",\"servings\":2,\"visibility\":\"PUBLIC\",\"origin\":\"CURATED\",\"userId\":2,\"ingredients\":[{\"ingredientId\":7,\"quantity\":3}]}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.origin").value("USER"))
                .andExpect(jsonPath("$.userId").value(1));
        Assertions.assertEquals(1, recipe.getIngredients().size());
        Assertions.assertEquals(0, new java.math.BigDecimal("3").compareTo(recipe.getIngredients().getFirst().getQuantity()));
        Assertions.assertFalse(recipe.getIngredients().contains(old));
        mvc.perform(put("/api/recipes/11").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Updated\",\"instructions\":\"Cook\",\"servings\":2,\"ingredients\":[]}"))
                .andExpect(status().isOk());
        Assertions.assertTrue(recipe.getIngredients().isEmpty());
        Assertions.assertEquals(RecipeVisibility.PUBLIC, recipe.getVisibility());
        verify(ingredients, never()).save(any());
    }

    @Test
    void rejectedReplacementLeavesMetadataAndIngredientCollectionUntouched() throws Exception {
        RecipeIngredient old = new RecipeIngredient(); old.setRecipe(recipe); old.setQuantity(new java.math.BigDecimal("1.5"));
        recipe.getIngredients().add(old);
        for (String values : List.of("[{\"ingredientId\":7,\"quantity\":1},{\"ingredientId\":99,\"quantity\":1}]",
                "[{\"ingredientId\":7,\"quantity\":1},{\"ingredientId\":7,\"quantity\":2}]",
                "[{\"ingredientId\":7,\"quantity\":0}]")) {
            mvc.perform(put("/api/recipes/11").header("Authorization", "Bearer " + ownerToken)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"name\":\"Wrong\",\"instructions\":\"Wrong\",\"servings\":2,\"visibility\":\"PUBLIC\",\"ingredients\":" + values + "}"))
                    .andExpect(status().is4xxClientError());
            Assertions.assertEquals("Lentil soup", recipe.getName());
            Assertions.assertEquals(RecipeVisibility.PRIVATE, recipe.getVisibility());
            Assertions.assertSame(old, recipe.getIngredients().getFirst());
        }
        verify(recipes, never()).save(any());
    }

    @Test
    void visibilityCanBeRevokedAndOwnerRetainsAccess() throws Exception {
        recipe.setVisibility(RecipeVisibility.PUBLIC);
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + otherToken)).andExpect(status().isOk());
        mvc.perform(put("/api/recipes/11").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Soup\",\"instructions\":\"Cook\",\"servings\":2,\"visibility\":\"PRIVATE\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.visibility").value("PRIVATE"));
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + otherToken)).andExpect(status().isNotFound());
        mvc.perform(get("/api/recipes/11/ingredients").header("Authorization", "Bearer " + otherToken)).andExpect(status().isNotFound());
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + ownerToken)).andExpect(status().isOk());
    }

    @Test
    void recipeUsedByAnyMealPlanCannotBeDeletedAndForeignKeyRaceIsHandled() throws Exception {
        MealPlanRepository plans = context.getBean(MealPlanRepository.class);
        when(plans.existsByRecipeId(11L)).thenReturn(true);
        mvc.perform(delete("/api/recipes/11").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("used in a meal plan")));
        verify(recipes, never()).delete(any());
        when(plans.existsByRecipeId(11L)).thenReturn(false);
        doThrow(new org.springframework.dao.DataIntegrityViolationException("private-fk-details")).when(recipes).flush();
        mvc.perform(delete("/api/recipes/11").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isBadRequest())
                .andExpect(content().string(not(containsString("private-fk-details"))));
    }

    @Test
    void collectionsAreCuratedOnlyOrPublicUserOnlyAndNeverAcceptClientOwner() throws Exception {
        Recipe curated = new Recipe(); curated.setId(90L); curated.setOrigin(RecipeOrigin.CURATED); curated.setVisibility(RecipeVisibility.PUBLIC);
        Recipe publicUser = new Recipe(); publicUser.setId(91L); publicUser.setUser(other); publicUser.setVisibility(RecipeVisibility.PUBLIC);
        when(recipes.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.CURATED, RecipeVisibility.PUBLIC)).thenReturn(List.of(curated));
        when(recipes.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.USER, RecipeVisibility.PUBLIC)).thenReturn(List.of(publicUser));
        mvc.perform(get("/api/recipes").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].origin").value("CURATED"));
        mvc.perform(get("/api/recipes/community?userId=1").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].origin").value("USER"))
                .andExpect(jsonPath("$[0].visibility").value("PUBLIC")).andExpect(jsonPath("$[0].userId").value(2));
        mvc.perform(get("/api/recipes/community")).andExpect(status().isUnauthorized());
        verify(recipes).findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.CURATED, RecipeVisibility.PUBLIC);
        verify(recipes).findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.USER, RecipeVisibility.PUBLIC);
    }

    @Test
    void decimalAndLineUnitRoundTripDoesNotMutateSharedDefault() throws Exception {
        mvc.perform(put("/api/recipes/11/ingredients/21").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":0.123456789012,\"unit\":\"kg\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.unit").value("kg"));
        var capture = org.mockito.ArgumentCaptor.forClass(RecipeIngredient.class); verify(lines).save(capture.capture());
        Assertions.assertEquals(new java.math.BigDecimal("0.123456789012"), capture.getValue().getQuantity());
        Assertions.assertEquals("cup", capture.getValue().getIngredient().getUnit());
        mvc.perform(put("/api/recipes/11/ingredients/21").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"ingredientId\":7,\"quantity\":1}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.unit").value("kg"));
    }

    @Test
    void unknownNutritionIsNullAndPrivateRecipesRemainUnreadable() throws Exception {
        recipe.setServings(2);
        mvc.perform(get("/api/recipes/11/nutrition").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UNAVAILABLE"))
                .andExpect(jsonPath("$.totals").isEmpty()).andExpect(jsonPath("$.perServing").isEmpty());
        mvc.perform(get("/api/recipes/11/nutrition").header("Authorization", "Bearer " + otherToken)).andExpect(status().isNotFound());
        mvc.perform(get("/api/recipes/11/nutrition")).andExpect(status().isUnauthorized());
    }

    @Test
    void nutritionCurationRequiresJwtAndSeparateSecretAndReviewedRequest() throws Exception {
        String path = "/api/nutrition/curation/ingredients/7/mapping";
        String body = "{\"externalFoodId\":\"123\",\"preparationState\":\"raw\",\"reviewed\":true}";
        mvc.perform(get("/api/nutrition/curation/foods?query=rice")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/nutrition/curation/foods?query=rice").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isForbidden());
        mvc.perform(post(path).header("Authorization", "Bearer " + otherToken).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());
        mvc.perform(post(path).header("Authorization", "Bearer " + ownerToken).header("X-Nutrition-Curator-Token", "wrong")
                .contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isForbidden());
        mvc.perform(post(path).header("Authorization", "Bearer " + ownerToken).header("X-Nutrition-Curator-Token", "test-curator-token-".repeat(3))
                .contentType(MediaType.APPLICATION_JSON).content(body.replace("true", "false"))).andExpect(status().isBadRequest());
        var remote = context.getBean(com.akletna.backend.nutrition.UsdaFoodClient.class);
        when(remote.search("rice")).thenThrow(new com.akletna.backend.nutrition.ProviderUnavailableException());
        mvc.perform(get("/api/nutrition/curation/foods?query=rice").header("Authorization", "Bearer " + ownerToken)
                .header("X-Nutrition-Curator-Token", "test-curator-token-".repeat(3)))
                .andExpect(status().isServiceUnavailable()).andExpect(jsonPath("$.message").value("Nutrition provider is unavailable. Try again later."));
        verify(context.getBean(NutritionMappingService.class), never()).map(any(),any(),any());
    }

    @Test
    void newUserRecipesRequirePositiveKnownServings() throws Exception {
        for (String count : List.of("null", "0", "-1")) {
            mvc.perform(post("/api/recipes").header("Authorization", "Bearer " + ownerToken)
                    .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Soup\",\"instructions\":\"Cook\",\"servings\":" + count + "}"))
                    .andExpect(status().isBadRequest());
        }
        verify(recipes, never()).save(any());
    }

    private static User user(Long id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setName("Test User");
        return user;
    }

    @Test
    void savedEndpointsRequireJwtAndIgnoreCallerIdentity() throws Exception {
        mvc.perform(put("/api/recipes/11/save")).andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/recipes/11/save")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/recipes/saved")).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/recipes/11/save?userId=2").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"userId\":2,\"origin\":\"CURATED\"}"))
                .andExpect(status().isNoContent());
        var saves = context.getBean(SavedRecipeRepository.class);
        verify(saves).existsByUserIdAndRecipeId(1L, 11L);
        verify(saves).save(any(SavedRecipe.class));
        verify(recipes, never()).save(any());
        org.junit.jupiter.api.Assertions.assertEquals(RecipeOrigin.USER, recipe.getOrigin());
        org.junit.jupiter.api.Assertions.assertEquals(RecipeVisibility.PRIVATE, recipe.getVisibility());
    }

    @Test
    void duplicateSaveAndRepeatedUnsaveAreIdempotentAndUserScoped() throws Exception {
        var saves = context.getBean(SavedRecipeRepository.class);
        when(saves.existsByUserIdAndRecipeId(1L, 11L)).thenReturn(false, true);
        for (int i=0; i<2; i++) mvc.perform(put("/api/recipes/11/save").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isNoContent());
        verify(saves, times(1)).save(any());
        for (int i=0; i<2; i++) mvc.perform(delete("/api/recipes/11/save?userId=1").header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isNoContent());
        verify(saves, times(2)).removeForUser(2L, 11L);
        verify(saves, never()).removeForUser(1L, 11L);
    }

    @Test
    void privateSavesAreHiddenButPublicAndCuratedRecipesAreReadable() throws Exception {
        mvc.perform(put("/api/recipes/11/save").header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.message").value("Recipe not found."));
        recipe.setVisibility(RecipeVisibility.PUBLIC);
        mvc.perform(put("/api/recipes/11/save").header("Authorization", "Bearer " + otherToken)).andExpect(status().isNoContent());
        recipe.setOrigin(RecipeOrigin.CURATED);
        mvc.perform(put("/api/recipes/11/save").header("Authorization", "Bearer " + ownerToken)).andExpect(status().isNoContent());
        verify(recipes, never()).save(any());
    }

    @Test
    void savedListUsesJwtScopeRepositoryOrderAndDetailMetadata() throws Exception {
        var saves = context.getBean(SavedRecipeRepository.class);
        var second = new Recipe(); second.setId(12L); second.setName("Second"); second.setUser(owner);
        when(saves.findReadableByUser(1L)).thenReturn(List.of(new SavedRecipe(owner, second), new SavedRecipe(owner, recipe)));
        when(saves.existsByUserIdAndRecipeId(1L, 11L)).thenReturn(true);
        mvc.perform(get("/api/recipes/saved?userId=2").header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(12))
                .andExpect(jsonPath("$[1].id").value(11)).andExpect(jsonPath("$[0].saved").value(true))
                .andExpect(jsonPath("$[0].savedAt").exists()).andExpect(jsonPath("$[0].saveCount").isEmpty());
        mvc.perform(get("/api/recipes/saved").header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + ownerToken))
                .andExpect(jsonPath("$.saved").value(true)).andExpect(jsonPath("$.saveCount").isEmpty());
    }

    @Test
    void publicCountsComeFromRowsAndPrivatizingRevokesOtherSaves() throws Exception {
        recipe.setVisibility(RecipeVisibility.PUBLIC);
        var saves = context.getBean(SavedRecipeRepository.class);
        var count = mock(SavedRecipeRepository.RecipeCount.class);
        when(count.getRecipeId()).thenReturn(11L); when(count.getSaveCount()).thenReturn(2L);
        when(saves.countsForRecipes(List.of(11L))).thenReturn(List.of(count));
        when(recipes.findByOriginAndVisibilityOrderByCreatedAtDesc(RecipeOrigin.USER, RecipeVisibility.PUBLIC)).thenReturn(List.of(recipe));
        mvc.perform(get("/api/recipes/community").header("Authorization", "Bearer " + otherToken))
                .andExpect(jsonPath("$[0].saveCount").value(2)).andExpect(jsonPath("$[0].origin").value("USER"));
        mvc.perform(put("/api/recipes/11").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Soup\",\"instructions\":\"Cook\",\"servings\":3,\"visibility\":\"PRIVATE\"}"))
                .andExpect(status().isOk());
        verify(saves).removeOtherUsers(11L, 1L);
        mvc.perform(get("/api/recipes/11").header("Authorization", "Bearer " + otherToken)).andExpect(status().isNotFound());
    }

    @Test void planningIgnoresClientSnapshotContentAndKeepsServerValues() throws Exception {
        stubPlan();
        mvc.perform(post("/api/meal-plans").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"recipeId\":11,\"date\":\"2027-04-05\",\"mealType\":\"DINNER\",\"plannedServings\":2,\"recipeName\":\"Forged\",\"snapshot\":{\"name\":\"Forged\",\"baseServings\":999,\"ingredients\":[{\"quantity\":999999}]}}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.recipeName").value("Lentil soup"))
                .andExpect(jsonPath("$.recipeBaseServings").value(4)).andExpect(jsonPath("$.snapshotState").value("READY"));
        verify(recipes,never()).save(any());verify(lines,never()).save(any());
    }

    private MealPlan stubPlan() {
        var plans = context.getBean(MealPlanRepository.class);
        var plan = new MealPlan(owner, recipe, java.time.LocalDate.of(2026, 10, 5), MealType.DINNER, java.time.LocalDateTime.now());
        plan.setId(31L); plan.setPlannedServings(4); plan.captureRecipe(recipe);
        when(plans.findByIdAndUser(31L, owner)).thenReturn(Optional.of(plan));
        when(plans.save(any())).thenAnswer(i -> { MealPlan saved=i.getArgument(0); saved.setId(31L); return saved; });
        return plan;
    }

    @Test
    void plannedServingsCreateAndUpdatePreserveSourceAndUseJwtIdentity() throws Exception {
        var plan = stubPlan();
        mvc.perform(post("/api/meal-plans").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"recipeId\":11,\"date\":\"2026-10-05\",\"mealType\":\"DINNER\",\"plannedServings\":6,\"userId\":2}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.plannedServings").value(6));
        mvc.perform(put("/api/meal-plans/31").header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON).content("{\"recipeId\":11,\"date\":\"2026-10-05\",\"mealType\":\"DINNER\",\"plannedServings\":2}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.plannedServings").value(2));
        mvc.perform(get("/api/meal-plans/31").header("Authorization", "Bearer " + ownerToken))
                .andExpect(jsonPath("$.plannedServings").value(2));
        org.junit.jupiter.api.Assertions.assertEquals(2, plan.getPlannedServings());
        org.junit.jupiter.api.Assertions.assertEquals(4, recipe.getServings());
        org.junit.jupiter.api.Assertions.assertSame(owner, plan.getUser());
        verify(recipes, never()).save(any()); verify(lines, never()).save(any());
    }

    @Test
    void plannedServingsRejectMissingNullNonpositiveFractionsAndCoercion() throws Exception {
        stubPlan();
        for (String value : List.of("", "null", "0", "-1", "2.5", "2.0", "\"3\"", "true", "2147483648")) {
            String body="{\"recipeId\":11,\"date\":\"2026-10-05\",\"mealType\":\"DINNER\""+(value.isEmpty()?"":",\"plannedServings\":"+value)+"}";
            mvc.perform(post("/api/meal-plans").header("Authorization", "Bearer " + ownerToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
            mvc.perform(put("/api/meal-plans/31").header("Authorization", "Bearer " + ownerToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
        }
        verify(context.getBean(MealPlanRepository.class), never()).save(any());
    }

    @Test
    void plannedServingMutationsRemainAuthenticatedAndOwnerScoped() throws Exception {
        stubPlan();
        String body="{\"recipeId\":11,\"date\":\"2026-10-05\",\"mealType\":\"DINNER\",\"plannedServings\":6}";
        mvc.perform(post("/api/meal-plans").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/meal-plans/31").contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/meal-plans/31")).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/meal-plans/31").header("Authorization", "Bearer "+otherToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNotFound());
        mvc.perform(delete("/api/meal-plans/31").header("Authorization", "Bearer "+otherToken)).andExpect(status().isNotFound());
        mvc.perform(post("/api/meal-plans").header("Authorization", "Bearer "+otherToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isNotFound());
        recipe.setVisibility(RecipeVisibility.PUBLIC); recipe.setOrigin(RecipeOrigin.CURATED);
        mvc.perform(post("/api/meal-plans").header("Authorization", "Bearer "+otherToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isCreated());
        verify(recipes, never()).save(any());
    }

    @Test
    void invalidLegacyRecipeBaselineIsNeverScaledOrDefaulted() throws Exception {
        var plan=stubPlan(); plan.setPlannedServings(null);
        when(context.getBean(MealPlanRepository.class).findByIdAndUser(31L, owner)).thenReturn(Optional.of(new MealPlan(owner,recipe,plan.getDate(),plan.getMealType(),plan.getCreatedAt())));
        mvc.perform(get("/api/meal-plans/31").header("Authorization", "Bearer "+ownerToken)).andExpect(jsonPath("$.plannedServings").isEmpty());
        for (Integer base : java.util.Arrays.asList(null, 0, -1)) {
            recipe.setServings(base);
            String body="{\"recipeId\":11,\"date\":\"2026-10-05\",\"mealType\":\"DINNER\",\"plannedServings\":6}";
            mvc.perform(post("/api/meal-plans").header("Authorization", "Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
            mvc.perform(put("/api/meal-plans/31").header("Authorization", "Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isBadRequest());
        }
        verify(context.getBean(MealPlanRepository.class), never()).save(any());
    }

    @Test void profileEndpointsRequireJwtAndIgnoreSubmittedIdentityAndEmail() throws Exception {
        mvc.perform(get("/api/users/me/profile")).andExpect(status().isUnauthorized());
        mvc.perform(put("/api/users/me/profile").contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Changed\"}"))
            .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/users/me/profile?userId=2").header("Authorization","Bearer "+ownerToken))
            .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(1)).andExpect(header().string("Cache-Control","no-store"));
        mvc.perform(put("/api/users/me/profile").header("Authorization","Bearer "+ownerToken).contentType(MediaType.APPLICATION_JSON)
            .content("{\"name\":\"Changed\",\"userId\":2,\"email\":\"other@example.test\"}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(1)).andExpect(jsonPath("$.name").value("Changed"));
        org.junit.jupiter.api.Assertions.assertEquals("owner@example.test",owner.getEmail());
        verify(users).save(owner);
    }

    @Configuration
    @EnableWebMvc
    @EnableWebSecurity
    @Import({RequestJsonConfig.class, SecurityConfig.class, JwtAuthenticationFilter.class, JwtAuthenticationEntryPoint.class, ApiAccessDeniedHandler.class,
            AuthController.class, UserController.class, ProfileController.class, ProfileService.class, RecipeController.class, MealPlanController.class, PantryController.class, PantryService.class,
            PantryMatchingController.class, PantryMatchingService.class,
            RecommendationController.class, RecommendationService.class, RecommendationPolicy.class,
            UserPreferenceController.class, UserPreferenceService.class, RecipeEvaluationService.class, RecipeDiscoveryService.class,
            RecipeIngredientController.class, IngredientController.class, GlobalExceptionHandler.class,
            UserService.class, RecipeService.class, SavedRecipeService.class, MealPlanService.class, RecipeIngredientService.class, IngredientService.class, RecipeNutritionService.class, com.akletna.backend.nutrition.UnavailableNutritionProvider.class})
    static class IsolatedConfiguration {
        @Bean com.akletna.backend.nutrition.UsdaFoodClient usdaClient() { return mock(com.akletna.backend.nutrition.UsdaFoodClient.class); }
        @Bean NutritionMappingService nutritionMappings() { return mock(NutritionMappingService.class); }
        @Bean NutritionMappingController nutritionCuration() {
            return new NutritionMappingController(usdaClient(), nutritionMappings(), "test-curator-token-".repeat(3));
        }
        @Bean JwtService jwtService() { return new JwtService(Encoders.BASE64.encode(TEST_KEY.getEncoded()), 86400000); }
        @Bean UserRepository users() { return mock(UserRepository.class); }
        @Bean RecipeRepository recipes() { return mock(RecipeRepository.class); }
        @Bean IngredientRepository ingredients() { return mock(IngredientRepository.class); }
        @Bean RecipeIngredientRepository lines() { return mock(RecipeIngredientRepository.class); }
        @Bean MealPlanRepository mealPlans() { return mock(MealPlanRepository.class); }
        @Bean SavedRecipeRepository savedRecipes() { return mock(SavedRecipeRepository.class); }
        @Bean PantryItemRepository pantryItems() { return mock(PantryItemRepository.class); }
        @Bean UserPreferenceRepository preferences() { return mock(UserPreferenceRepository.class); }
        @Bean IngredientClassificationRepository ingredientClassifications() { return mock(IngredientClassificationRepository.class); }
        @Bean RecipeClassificationRepository recipeClassifications() { return mock(RecipeClassificationRepository.class); }
        @Bean IngredientNutritionRepository storedProfiles() { return mock(IngredientNutritionRepository.class); }
        @Bean FoodMetadataCurationController foodCuration() { return new FoodMetadataCurationController(ingredients(),recipes(),ingredientClassifications(),recipeClassifications(),"test-curator-token-".repeat(3)); }
    }
}
