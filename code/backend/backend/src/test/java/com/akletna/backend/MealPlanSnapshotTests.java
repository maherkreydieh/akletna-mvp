package com.akletna.backend;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.exception.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.*;
import org.junit.jupiter.api.*;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class MealPlanSnapshotTests {
    final MealPlanRepository plans=mock(MealPlanRepository.class);
    final UserService users=mock(UserService.class);
    final RecipeService recipes=mock(RecipeService.class);
    final User user=new User();
    final Recipe source=new Recipe();
    final Ingredient rice=new Ingredient();
    final RecipeIngredient line=new RecipeIngredient();
    final MealPlanService service=new MealPlanService(plans,users,recipes);
    MealPlan persisted;
    @BeforeEach void setup() {
        user.setId(1L); user.setEmail("snapshot@example.test");
        source.setId(11L);source.setName("Original rice");source.setServings(4);source.setUser(user);
        rice.setId(7L);rice.setName("Rice");line.setIngredient(rice);line.setQuantity(new BigDecimal("400"));line.setUnit("g");source.getIngredients().add(line);
        when(users.getUserByEmail(user.getEmail())).thenReturn(user);
        when(recipes.getRecipeEntityAndVerifyReadable(11L,user.getEmail())).thenReturn(source);
        when(plans.save(any())).thenAnswer(c->{persisted=c.getArgument(0);persisted.setId(31L);return persisted;});
        when(plans.findByIdAndUser(31L,user)).thenAnswer(c->Optional.ofNullable(persisted));
    }
    MealPlanRequest request(long recipeId,int servings) {
        var request=new MealPlanRequest(recipeId,LocalDate.of(2027,4,5),MealType.LUNCH);request.setPlannedServings(servings);return request;
    }
    @Test void creationFreezesDisplayIdentityUnitsAndPreciseAmounts() {
        var response=service.createMealPlan(request(11,2),user.getEmail());
        var snapshot=persisted.getSnapshot();
        assertEquals("READY",response.getSnapshotState());assertEquals(4,response.getRecipeBaseServings());
        line.setQuantity(new BigDecimal("1600"));line.setUnit("kg");rice.setName("Renamed rice");source.setName("New name");source.setServings(8);
        var read=service.getMealPlanById(31L,user.getEmail());
        assertEquals("Original rice",read.getRecipeName());assertEquals(4,read.getRecipeBaseServings());
        var ingredient=snapshot.getIngredients().getFirst();
        assertEquals(7L,ingredient.getIngredientId());assertEquals("Rice",ingredient.getIngredientName());assertEquals("g",ingredient.getUnit());
        assertEquals(new BigDecimal("400"),ingredient.getQuantity());assertNotNull(snapshot.getCapturedAt());
        assertThrows(UnsupportedOperationException.class,()->snapshot.getIngredients().clear());
        verify(recipes,never()).updateRecipe(any(),any(),any());
    }
    @Test void servingsAndMovesKeepSnapshotEvenWhenSourceBecomesUnreadable() {
        service.createMealPlan(request(11,2),user.getEmail());var snapshot=persisted.getSnapshot();
        when(recipes.getRecipeEntityAndVerifyReadable(11L,user.getEmail())).thenThrow(new ResourceNotFoundException("private"));
        source.setServings(8);line.setQuantity(new BigDecimal("1600"));
        var update=request(11,4);update.setDate(LocalDate.of(2027,4,6));update.setMealType(MealType.DINNER);
        var response=service.updateMealPlan(31L,update,user.getEmail());
        assertSame(snapshot,persisted.getSnapshot());assertEquals(update.getDate(),response.getDate());assertEquals(4,response.getPlannedServings());
        assertEquals(new BigDecimal("400.00"),QuantityScaling.effectiveQuantity(snapshot.getIngredients().getFirst().getQuantity(),4,snapshot.getBaseServings()).rounded(2));
    }
    @Test void laterOccurrenceAndReplacementCaptureNewValuesAndFailedReplacementPreservesOld() {
        service.createMealPlan(request(11,2),user.getEmail());var first=persisted;
        source.setServings(8);source.setName("New rice");line.setQuantity(new BigDecimal("1600"));
        service.createMealPlan(request(11,2),user.getEmail());var second=persisted;
        assertEquals(4,first.getSnapshot().getBaseServings());assertEquals(8,second.getSnapshot().getBaseServings());
        assertNotSame(first.getSnapshot(),second.getSnapshot());
        var replacement=new Recipe();replacement.setId(12L);replacement.setName("Replacement");replacement.setServings(0);
        when(recipes.getRecipeEntityAndVerifyReadable(12L,user.getEmail())).thenReturn(replacement);
        var old=second.getSnapshot();assertThrows(BadRequestException.class,()->service.updateMealPlan(31L,request(12,2),user.getEmail()));
        assertSame(old,second.getSnapshot());assertSame(source,second.getRecipe());
        replacement.setServings(3);service.updateMealPlan(31L,request(12,2),user.getEmail());
        assertEquals("Replacement",second.getSnapshot().getName());assertTrue(second.getSnapshot().getIngredients().isEmpty());assertSame(replacement,second.getRecipe());
    }
    @Test void invalidCreationCannotPersistPartialSnapshot() {
        line.setQuantity(new BigDecimal("0.0000000000001"));
        assertThrows(BadRequestException.class,()->service.createMealPlan(request(11,2),user.getEmail()));verify(plans,never()).save(any());
        line.setQuantity(BigDecimal.ZERO);assertThrows(BadRequestException.class,()->MealPlanSnapshot.capture(source));
        line.setQuantity(new BigDecimal("1.123456789012"));
        assertEquals(line.getQuantity(),MealPlanSnapshot.capture(source).getIngredients().getFirst().getQuantity());
    }
    @Test void groceryVersionsAggregateFromSnapshotsWithNoLiveRecipeQueries() {
        service.createMealPlan(request(11,2),user.getEmail());var first=persisted;
        source.setServings(8);line.setQuantity(new BigDecimal("1600"));rice.setName("Later name");
        service.createMealPlan(request(11,2),user.getEmail());var second=persisted;
        var lists=mock(GroceryListRepository.class);var items=mock(GroceryItemRepository.class);var liveLines=mock(RecipeIngredientRepository.class);
        when(plans.findByUserOrderByDateAscMealTypeAsc(user)).thenReturn(List.of(first,second));
        when(lists.findByUser(user)).thenReturn(Optional.empty());when(lists.save(any())).thenAnswer(c->c.getArgument(0));
        var grocery=grocery(lists,items);
        assertEquals(600.0,grocery.generateFromMealPlans(null,user.getEmail()).getItems().getFirst().getQuantity());
        first.setPlannedServings(4);
        var result=grocery.generateFromMealPlans(null,user.getEmail()).getItems().getFirst();
        assertEquals(800.0,result.getQuantity());assertEquals("Rice",result.getName());verifyNoInteractions(liveLines);
    }
    @Test void unresolvedLegacyPlanIsExplicitAndCannotReplaceExistingGroceries() {
        persisted=new MealPlan(user,source,LocalDate.now(),MealType.LUNCH,LocalDateTime.now());persisted.setId(31L);
        assertEquals("UNRESOLVED",service.getMealPlanById(31L,user.getEmail()).getSnapshotState());
        assertEquals("Unresolved planned meal",service.getMealPlanById(31L,user.getEmail()).getRecipeName());
        assertThrows(BadRequestException.class,()->service.updateMealPlan(31L,request(11,2),user.getEmail()));
        var lists=mock(GroceryListRepository.class);
        when(plans.findByUserOrderByDateAscMealTypeAsc(user)).thenReturn(List.of(persisted));
        var grocery=grocery(lists,mock(GroceryItemRepository.class));
        assertThrows(BadRequestException.class,()->grocery.generateFromMealPlans(null,user.getEmail()));verifyNoInteractions(lists);
    }
    private GroceryListService grocery(GroceryListRepository lists,GroceryItemRepository items) {
        var locked=mock(UserRepository.class);when(locked.findLockedById(1L)).thenReturn(Optional.of(user));
        return new GroceryListService(lists,items,plans,users,locked,mock(GroceryContributionRepository.class),recipes,
                mock(PantryItemRepository.class),mock(PantryMatchingService.class));
    }
}
