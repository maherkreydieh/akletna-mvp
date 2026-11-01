package com.akletna.backend;

import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.*;
import com.akletna.backend.exception.*;
import org.junit.jupiter.api.*;
import org.springframework.test.util.ReflectionTestUtils;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class GroceryShortageTests {
    final GroceryListRepository lists=mock(GroceryListRepository.class);
    final GroceryItemRepository items=mock(GroceryItemRepository.class);
    final MealPlanRepository plans=mock(MealPlanRepository.class);
    final UserService users=mock(UserService.class);
    final UserRepository owners=mock(UserRepository.class);
    final GroceryContributionRepository contributions=mock(GroceryContributionRepository.class);
    final RecipeService recipes=mock(RecipeService.class);
    final PantryItemRepository pantry=mock(PantryItemRepository.class);
    final RecipeEvaluationService evaluation=mock(RecipeEvaluationService.class);
    final List<GroceryContribution> sources=new ArrayList<>();
    final User user=new User();
    final Recipe recipe=new Recipe();
    final Ingredient rice=new Ingredient();
    final PantryItem stock=new PantryItem();
    GroceryList list;
    GroceryListService service;
    @BeforeEach void setup() {
        user.setId(1L);user.setEmail("owner@example.test");
        rice.setId(10L);rice.setName("Rice");rice.setUnit("g");
        recipe.setId(20L);recipe.setName("Rice recipe");recipe.setServings(4);
        line("500","g");stock.setUser(user);stock.setIngredient(rice);stock.setQuantity(new BigDecimal("300"));stock.setUnit("g");
        list=new GroceryList(user,LocalDateTime.now());list.setId(30L);
        when(users.getUserByEmail(user.getEmail())).thenReturn(user);
        when(owners.findLockedById(1L)).thenReturn(Optional.of(user));
        when(recipes.getRecipeForGrocery(20L,user.getEmail())).thenReturn(recipe);
        when(pantry.findForUser(1L)).thenAnswer(i->List.of(stock));
        when(lists.findByUser(user)).thenReturn(Optional.of(list));
        when(lists.save(any())).thenAnswer(i->i.getArgument(0));
        when(contributions.findByGroceryListOrderByIdAsc(list)).thenAnswer(i->List.copyOf(sources));
        when(contributions.save(any())).thenAnswer(i->{GroceryContribution c=i.getArgument(0);ReflectionTestUtils.setField(c,"id",100L+sources.size());sources.add(c);return c;});
        doAnswer(i->{sources.remove(i.getArgument(0));return null;}).when(contributions).delete(any());
        service=new GroceryListService(lists,items,plans,users,owners,contributions,recipes,pantry,new PantryMatchingService(users,recipes,pantry,evaluation));
    }
    void line(String quantity,String unit) {
        var line=new RecipeIngredient();line.setRecipe(recipe);line.setIngredient(rice);line.setQuantity(new BigDecimal(quantity));line.setUnit(unit);
        recipe.setIngredients(new ArrayList<>(List.of(line)));
    }
    com.akletna.backend.dto.RecipeShortageResponse add(int servings){return service.addShortages(20L,servings,user.getEmail());}
    double total(){return list.getItems().getFirst().getQuantity();}
    @Test void exactShortageUsesServerInputsAndLeavesOtherSystemsUntouched(){
        assertEquals("200",add(4).ingredients().getFirst().quantity());assertEquals(200,total());
        assertEquals(new BigDecimal("300"),stock.getQuantity());assertEquals(new BigDecimal("500"),recipe.getIngredients().getFirst().getQuantity());
        verify(pantry,never()).save(any());verify(recipes,never()).getRecipeEntityAndVerifyReadable(anyLong(),anyString());verifyNoInteractions(evaluation,plans,items);
    }
    @Test void servingScalePrecedesSubtraction(){line("800","g");stock.setQuantity(new BigDecimal("100"));assertEquals("300",add(2).ingredients().getFirst().quantity());}
    @Test void enoughDoesNotCreateContribution(){line("200","g");assertEquals("NOTHING_TO_ADD",add(4).status());assertTrue(sources.isEmpty());verify(lists,never()).save(any());}
    @Test void unknownQuantityIsExplicitAndNotZero(){stock.setQuantity(null);stock.setUnit(null);var result=add(4);assertEquals("PRESENT_QUANTITY_UNKNOWN",result.ingredients().getFirst().status());assertNull(result.ingredients().getFirst().quantity());assertTrue(sources.isEmpty());}
    @Test void incompatibleUnitNeverInventsDensity(){line("2","cup");var result=add(4);assertEquals("PRESENT_INCOMPARABLE",result.ingredients().getFirst().status());assertNull(result.ingredients().getFirst().quantity());assertTrue(sources.isEmpty());}
    @Test void missingCountUsesFullRequirementWithNonemptyPantry(){var other=new Ingredient();other.setId(11L);stock.setIngredient(other);line("2","pieces");assertEquals("2",add(4).ingredients().getFirst().quantity());assertEquals(2,total());}
    @Test void emptyPantryDoesNotImplicitlyAddEverything(){when(pantry.findForUser(1L)).thenReturn(List.of());assertEquals("PANTRY_EMPTY",add(4).status());assertTrue(sources.isEmpty());}
    @Test void massNormalizationIsExact(){line("0.5","kg");assertEquals("200",add(4).ingredients().getFirst().quantity());assertEquals("g",list.getItems().getFirst().getUnit());}
    @Test void volumeNormalizationIsExact(){line("1","L");stock.setUnit("mL");assertEquals("700",add(4).ingredients().getFirst().quantity());}
    @Test void duplicateKeepsCapturedAmountNameAndPurchasedCheck(){add(4);list.getItems().getFirst().setChecked(true);line("999","kg");recipe.setName("Later name");var repeat=add(4);assertEquals("ALREADY_ADDED",repeat.status());assertEquals("Rice recipe",repeat.recipeName());assertEquals("200",repeat.ingredients().getFirst().quantity());assertTrue(list.getItems().getFirst().isChecked());assertEquals(1,sources.size());}
    @Test void aggregationAndRemovalKeepOtherRecipeAndPlanSources(){
        var first=add(4);
        sources.add(new GroceryContribution(list,"RECIPE_SHORTAGE","RECIPE:21:4","Other",21L,4,List.of(new GroceryContributionLine(10L,"Rice","SHORTAGE",QuantityScaling.Quantity.of(new BigDecimal("300")),"g"))));
        sources.add(new GroceryContribution(list,"PLANNED_MEAL","PLAN","Weekly",null,null,List.of(new GroceryContributionLine(10L,"Rice","REQUIRED",QuantityScaling.Quantity.of(new BigDecimal("500")),"g"))));
        var result=service.removeContribution(first.contributionId(),user.getEmail());assertEquals(800,result.getItems().getFirst().getQuantity());assertEquals(2,result.getContributions().size());
    }
    @Test void regenerationPreservesShortageAndResetsChecks(){add(4);list.getItems().getFirst().setChecked(true);when(plans.findByUserOrderByDateAscMealTypeAsc(user)).thenReturn(List.of());var result=service.generateFromMealPlans(null,user.getEmail());assertEquals(200,result.getItems().getFirst().getQuantity());assertFalse(result.getItems().getFirst().isChecked());}
    @Test void foreignContributionCannotBeRemoved(){add(4);assertThrows(ResourceNotFoundException.class,()->service.removeContribution(999L,user.getEmail()));assertEquals(200,total());verify(contributions,never()).delete(any());}
    @Test void unreadableRecipeIsRejectedEvenForExistingAddition(){add(4);when(recipes.getRecipeForGrocery(20L,user.getEmail())).thenThrow(new ResourceNotFoundException("Recipe not found"));assertThrows(ResourceNotFoundException.class,()->add(4));assertEquals(200,total());}
    @Test void invalidServingDoesNotWrite(){assertThrows(BadRequestException.class,()->add(0));assertTrue(sources.isEmpty());verify(lists,never()).save(any());}
    @Test void recurringFractionsRemainExactUntilFinalHalfUpAggregation(){
        var other=new Ingredient();other.setId(99L);stock.setIngredient(other);
        recipe.setServings(3);line("0.005","g");
        for(long id=20;id<=22;id++) {
            recipe.setId(id);when(recipes.getRecipeForGrocery(id,user.getEmail())).thenReturn(recipe);
            service.addShortages(id,1,user.getEmail());
        }
        assertEquals(0.01,total());
        assertEquals(new java.math.BigInteger("600"),sources.getFirst().getLines().getFirst().quantity().denominator());
    }
}
