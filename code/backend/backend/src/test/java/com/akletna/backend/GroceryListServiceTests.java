package com.akletna.backend;

import com.akletna.backend.dto.GroceryGenerateRequest;
import com.akletna.backend.entity.*;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.GroceryListService;
import com.akletna.backend.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Grocery business rules without application configuration or a datasource. */
class GroceryListServiceTests {
    private final GroceryListRepository lists = mock(GroceryListRepository.class);
    private final GroceryItemRepository items = mock(GroceryItemRepository.class);
    private final MealPlanRepository plans = mock(MealPlanRepository.class);
    private final RecipeIngredientRepository lines = mock(RecipeIngredientRepository.class);
    private final UserService users = mock(UserService.class);
    private GroceryListService service;
    private User owner;
    private GroceryList list;
    private final LocalDate monday = LocalDate.of(2026, 9, 28);
    private final LocalDate sunday = LocalDate.of(2026, 10, 4);

    @BeforeEach
    void setUp() {
        owner = new User();
        owner.setId(1L);
        owner.setEmail("owner@example.test");
        list = new GroceryList(owner, LocalDateTime.of(2026, 1, 1, 0, 0));
        list.setId(10L);
        when(users.getUserByEmail(owner.getEmail())).thenReturn(owner);
        when(lists.findByUser(owner)).thenReturn(Optional.of(list));
        when(lists.save(any())).thenAnswer(call -> {
            GroceryList saved = call.getArgument(0);
            if (saved.getId() == null) saved.setId(10L);
            long nextId = 100;
            for (GroceryItem item : saved.getItems()) item.setId(nextId++);
            return saved;
        });
        var lockedUsers=mock(UserRepository.class);
        when(lockedUsers.findLockedById(1L)).thenReturn(Optional.of(owner));
        service = new GroceryListService(lists, items, plans, users,lockedUsers,mock(GroceryContributionRepository.class),
                mock(com.akletna.backend.service.RecipeService.class),mock(PantryItemRepository.class),mock(com.akletna.backend.service.PantryMatchingService.class));
    }

    @Test
    void readingAbsentListDoesNotCreateOrUpdateData() {
        when(lists.findByUser(owner)).thenReturn(Optional.empty());
        var response=service.getOrCreateUserGroceryList(owner.getEmail());
        assertNull(response.getId()); assertNull(response.getUpdatedAt());
        assertTrue(response.getItems().isEmpty()); assertTrue(response.getContributions().isEmpty());
        verify(lists,never()).save(any()); verifyNoInteractions(items,plans);
    }

    @Test
    void emptyWeekReplacesStaleStoredGroceriesInsteadOfFailing() {
        list.addItem(new GroceryItem(list, "Old groceries", 3.0, "cup", true));
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of());

        var response = generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail());

        assertTrue(response.getItems().isEmpty());
        assertTrue(list.getItems().isEmpty());
        assertTrue(response.getUpdatedAt().isAfter(LocalDateTime.of(2026, 1, 1, 0, 0)));
        verify(lists).save(list);
        verifyNoInteractions(lines, items);
    }

    @Test
    void aNewUserCanGenerateAnEmptyList() {
        when(lists.findByUser(owner)).thenReturn(Optional.empty());
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of());
        var response = generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail());
        assertNotNull(response.getId());
        assertTrue(response.getItems().isEmpty());
    }

    @Test
    void repeatedRecipesSumFullQuantitiesAndDifferentUnitsStaySeparate() {
        Recipe first = recipe(11L);
        Recipe second = recipe(12L);
        RecipeIngredient lentils = line(first, "Lentils", "cup", 1.5);
        RecipeIngredient salt = line(first, "Salt", null, 0.333);
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday))
                .thenReturn(List.of(plan(first), plan(first), plan(second)));
        snapshotLines(11L, List.of(lentils, salt));
        snapshotLines(12L, List.of(
                line(second, " lentils ", " CUP ", 2.0),
                line(second, "Lentils", "g", 100.0)));
        list.addItem(new GroceryItem(list, "Old groceries", 3.0, "cup", true));

        var response = generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail());

        assertEquals(3, response.getItems().size());
        assertEquals(5.0, response.getItems().get(0).getQuantity());
        assertEquals("cup", response.getItems().get(0).getUnit());
        assertEquals(0.67, response.getItems().get(1).getQuantity());
        assertEquals("", response.getItems().get(1).getUnit());
        assertEquals(100.0, response.getItems().get(2).getQuantity());
        assertEquals("g", response.getItems().get(2).getUnit());
        assertTrue(response.getItems().stream().noneMatch(item -> item.isChecked()));
        assertEquals(4, first.getServings());
        assertEquals(0, new java.math.BigDecimal("1.5").compareTo(lentils.getQuantity()));
        assertEquals(0, new java.math.BigDecimal("0.333").compareTo(salt.getQuantity()));
        verifyNoInteractions(lines);
        verify(lines, never()).save(any());
        verify(plans, never()).save(any());
    }

    @Test
    void mealsWithoutIngredientLinesProduceAnEmptyList() {
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of(plan(recipe(11L))));
        snapshotLines(11L, List.of());
        assertTrue(generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail()).getItems().isEmpty());
    }

    @Test
    void invertedRangeDoesNotWriteAndMissingBoundsPreserveExistingAllPlansBehavior() {
        assertThrows(BadRequestException.class, () ->
                generate(new GroceryGenerateRequest(sunday, monday), owner.getEmail()));
        verifyNoInteractions(plans, lists, lines, items);
        when(plans.findByUserOrderByDateAscMealTypeAsc(owner)).thenReturn(List.of());
        generate(null, owner.getEmail());
        verify(plans).findByUserOrderByDateAscMealTypeAsc(owner);
    }

    @Test
    void togglesAreScopedToTheOwnersListAndSavedStateCanBeRead() {
        GroceryItem item = new GroceryItem(list, "Lentils", 2.0, "cup", false);
        item.setId(100L);
        list.addItem(item);
        when(items.findByIdAndGroceryList(100L, list)).thenReturn(Optional.of(item));
        when(items.save(item)).thenReturn(item);
        assertTrue(service.toggleItemChecked(100L, owner.getEmail()).isChecked());
        assertTrue(service.getOrCreateUserGroceryList(owner.getEmail()).getItems().get(0).isChecked());
        assertFalse(service.toggleItemChecked(100L, owner.getEmail()).isChecked());
        verify(items, times(2)).save(item);
        verifyNoInteractions(plans, lines);
    }

    @Test
    void anItemOutsideTheOwnersListCannotBeToggled() {
        when(items.findByIdAndGroceryList(999L, list)).thenReturn(Optional.empty());
        assertThrows(ResourceNotFoundException.class, () -> service.toggleItemChecked(999L, owner.getEmail()));
        verify(items, never()).save(any());
    }

    @Test
    void plannedScalingRegenerationAndRepeatedMealsDoNotChangeSources() {
        Recipe recipe = recipe(11L);
        var meal = plan(recipe); meal.setPlannedServings(6);
        var rice = line(recipe, "Rice", "g", 300);
        var chicken = line(recipe, "Chicken", "g", 500);
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of(meal));
        snapshotLines(11L, List.of(rice, chicken));
        var request = new GroceryGenerateRequest(monday, sunday);
        var first = generate(request, owner.getEmail());
        assertEquals(450.0, first.getItems().get(0).getQuantity());
        assertEquals(750.0, first.getItems().get(1).getQuantity());
        list.getItems().getFirst().setChecked(true);
        meal.setPlannedServings(2);
        var second = generate(request, owner.getEmail());
        assertEquals(150.0, second.getItems().get(0).getQuantity());
        assertEquals(250.0, second.getItems().get(1).getQuantity());
        assertFalse(second.getItems().getFirst().isChecked());
        var repeat = plan(recipe); repeat.setPlannedServings(6);
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of(meal, repeat));
        var combined = generate(request, owner.getEmail());
        assertEquals(600.0, combined.getItems().get(0).getQuantity());
        assertEquals(1000.0, combined.getItems().get(1).getQuantity());
        assertEquals(4, recipe.getServings());
        assertEquals(0, new java.math.BigDecimal("300").compareTo(rice.getQuantity()));
        assertEquals("g", rice.getUnit());
        verify(lines, never()).save(any()); verify(plans, never()).save(any());
    }

    @Test
    void differentRecipeBaselinesAggregateOnlyAfterScaling() {
        var first = recipe(11L); var second = recipe(12L); second.setServings(2);
        var firstMeal = plan(first); firstMeal.setPlannedServings(2);
        var secondMeal = plan(second); secondMeal.setPlannedServings(4);
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of(firstMeal, secondMeal));
        snapshotLines(11L, List.of(line(first, "Rice", "g", 300)));
        snapshotLines(12L, List.of(line(second, "rice", "G", 200), line(second, "Rice", "cup", 1)));
        var result = generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail());
        assertEquals(550.0, result.getItems().get(0).getQuantity());
        assertEquals(2.0, result.getItems().get(1).getQuantity());
        assertEquals("cup", result.getItems().get(1).getUnit());
    }

    @Test
    void recurringDivisionKeepsExactHalfUpTiesUntilFinalAggregation() {
        var recipe = recipe(11L); recipe.setServings(3);
        var meal = plan(recipe); meal.setPlannedServings(1);
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of(meal, meal, meal));
        var tiny = line(recipe, "Tiny", "g", 0.005);
        snapshotLines(11L, List.of(tiny));
        var result = generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail());
        assertEquals(0.01, result.getItems().getFirst().getQuantity());
        var quantity = com.akletna.backend.service.QuantityScaling.effectiveQuantity(new java.math.BigDecimal("333.33"), 2, 3);
        assertEquals(new java.math.BigDecimal("222.22"), quantity.rounded(2));
        assertEquals(new java.math.BigDecimal("0.67"), com.akletna.backend.service.QuantityScaling.effectiveQuantity(java.math.BigDecimal.ONE, 2, 3).rounded(2));
    }

    @Test
    void malformedLegacyCountsAbortBeforeReplacingStoredGroceries() {
        var recipe = recipe(11L); var meal = plan(recipe);
        list.addItem(new GroceryItem(list, "Keep", 5.0, "g", true));
        when(plans.findByUserAndDateBetweenOrderByDateAscMealTypeAsc(owner, monday, sunday)).thenReturn(List.of(meal));
        for (Integer bad : java.util.Arrays.asList(null, 0, -1)) {
            meal.setPlannedServings(bad);
            assertThrows(BadRequestException.class, () -> generate(new GroceryGenerateRequest(monday, sunday), owner.getEmail()));
            meal.setPlannedServings(4); recipe.setServings(bad);
            assertThrows(BadRequestException.class, () -> MealPlanSnapshot.capture(recipe));
            recipe.setServings(4);
        }
        assertEquals("Keep", list.getItems().getFirst().getName());
        assertTrue(list.getItems().getFirst().isChecked());
        verify(lists, never()).save(any()); verifyNoInteractions(lines);
    }

    private final java.util.Map<Long,List<RecipeIngredient>> fixtureLines = new java.util.HashMap<>();
    private final java.util.List<MealPlan> fixturePlans = new java.util.ArrayList<>();
    private void snapshotLines(Long id, List<RecipeIngredient> values) { fixtureLines.put(id,values); }
    private com.akletna.backend.dto.GroceryListResponse generate(GroceryGenerateRequest request, String email) {
        // Build persisted snapshot fixtures once, after all ingredient fixtures are assembled.
        for (var plan : fixturePlans) if (plan.getSnapshot()==null) {
            plan.getRecipe().setIngredients(fixtureLines.getOrDefault(plan.getRecipe().getId(),List.of()));
            plan.captureRecipe(plan.getRecipe());
        }
        return service.generateFromMealPlans(request,email);
    }
    private Recipe recipe(long id) {
        Recipe recipe = new Recipe();
        recipe.setId(id);
        recipe.setName("Test recipe");
        recipe.setServings(4);
        recipe.setUser(owner);
        return recipe;
    }

    private MealPlan plan(Recipe recipe) {
        var plan = new MealPlan(owner, recipe, monday, MealType.LUNCH, LocalDateTime.now());
        plan.setPlannedServings(recipe.getServings());
        fixturePlans.add(plan); return plan;
    }

    private RecipeIngredient line(Recipe recipe, String name, String unit, double quantity) {
        Ingredient ingredient = new Ingredient();
        ingredient.setId((long) name.trim().toLowerCase(java.util.Locale.ROOT).hashCode());
        ingredient.setName(name);
        ingredient.setUnit("piece"); // Recipe-line units must override the shared default.
        RecipeIngredient line = new RecipeIngredient();
        line.setRecipe(recipe);
        line.setIngredient(ingredient);
        line.setQuantity(java.math.BigDecimal.valueOf(quantity)); line.setUnit(unit);
        return line;
    }

    @Test void normalizesMassVolumeAndOpaqueUnitsAfterScaling() {
        var a = recipe(11L); var b = recipe(12L); b.setServings(2);
        var mealA = plan(a); mealA.setPlannedServings(2);
        when(plans.findByUserOrderByDateAscMealTypeAsc(owner)).thenReturn(List.of(mealA, plan(b)));
        snapshotLines(11L, List.of(line(a,"Rice"," KG ",0.5), line(a,"Milk","ML",500), line(a,"Tomato","piece",2),line(a,"Rice","cup",1)));
        snapshotLines(12L, List.of(line(b,"Rice","g",300), line(b,"Milk","L",1), line(b,"Tomato","piece",3),line(b,"Rice","CUP",0.5),line(b,"Rice","mL",10)));
        var result = generate(null, owner.getEmail()).getItems();
        assertEquals(5,result.size());
        assertEquals(550.0,result.get(0).getQuantity()); assertEquals("g",result.get(0).getUnit());
        assertEquals(1250.0,result.get(1).getQuantity()); assertEquals("mL",result.get(1).getUnit());
        assertEquals(0,new java.math.BigDecimal("1.25").compareTo(result.get(1).getDisplayQuantity())); assertEquals("L",result.get(1).getDisplayUnit());
        assertEquals(4.0,result.get(2).getQuantity()); assertEquals("piece",result.get(2).getUnit());
        assertEquals(1.0,result.get(3).getQuantity()); assertEquals("cup",result.get(3).getUnit());
        assertEquals(10.0,result.get(4).getQuantity()); assertEquals("mL",result.get(4).getUnit());
    }

    @Test void compatibleUnitsRepeatExactlyAndRoundOnlyAfterCanonicalAggregation() {
        var recipe = recipe(11L); recipe.setServings(3);
        var meal = plan(recipe); meal.setPlannedServings(1);
        when(plans.findByUserOrderByDateAscMealTypeAsc(owner)).thenReturn(List.of(meal,meal,meal));
        snapshotLines(11L, List.of(line(recipe,"Rice","kg",0.000005),line(recipe,"Milk","L",0.75)));
        var result = generate(null,owner.getEmail()).getItems();
        assertEquals(0.01,result.get(0).getQuantity()); assertEquals("g",result.get(0).getUnit());
        assertEquals(750.0,result.get(1).getQuantity()); assertEquals("mL",result.get(1).getDisplayUnit());
    }

    @Test void separateIngredientIdsNeverMergeEvenWithIdenticalNamesAndCompatibleUnits() {
        var recipe = recipe(11L);
        var rice = line(recipe,"Rice","kg",1); rice.getIngredient().setId(100L);
        var otherRice = line(recipe,"Rice","g",500); otherRice.getIngredient().setId(101L);
        var flour = line(recipe,"Rice flour","g",200); flour.getIngredient().setId(102L);
        when(plans.findByUserOrderByDateAscMealTypeAsc(owner)).thenReturn(List.of(plan(recipe)));
        snapshotLines(11L, List.of(rice,otherRice,flour));
        var result = generate(null,owner.getEmail()).getItems();
        assertEquals(3,result.size()); assertEquals(1000.0,result.get(0).getQuantity());
        assertEquals(500.0,result.get(1).getQuantity()); assertEquals(200.0,result.get(2).getQuantity());
        assertEquals("kg",result.get(0).getDisplayUnit());
    }

    @Test void storedCanonicalQuantityAndPresentationSurviveReadAndToggle() {
        var item = new GroceryItem(list,"Rice",1500.01,"g",false); item.setId(100L); list.addItem(item);
        when(items.findByIdAndGroceryList(100L,list)).thenReturn(Optional.of(item)); when(items.save(item)).thenReturn(item);
        var response = service.toggleItemChecked(100L,owner.getEmail());
        assertTrue(response.isChecked()); assertEquals(1500.01,response.getQuantity());
        assertEquals(0,new java.math.BigDecimal("1.50001").compareTo(response.getDisplayQuantity()));
        assertEquals("kg",response.getDisplayUnit());
        assertEquals("kg",service.getOrCreateUserGroceryList(owner.getEmail()).getItems().getFirst().getDisplayUnit());
        assertEquals(1500.01,item.getQuantity()); assertEquals("g",item.getUnit());
    }
}
