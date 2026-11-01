package com.akletna.backend;

import com.akletna.backend.entity.*;
import com.akletna.backend.repository.PantryItemRepository;
import com.akletna.backend.service.*;
import com.akletna.backend.dto.PantryMatchesResponse.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PantryMatchingTests {
    UserService users;
    RecipeService recipes;
    PantryItemRepository pantry;
    PantryMatchingService service;
    User user;
    @BeforeEach void setup() {
        users=mock(UserService.class);recipes=mock(RecipeService.class);pantry=mock(PantryItemRepository.class);
        service=new PantryMatchingService(users,recipes,pantry,mock(RecipeEvaluationService.class));
        user=new User();user.setId(1L);
        when(users.getUserByEmail("a@example.test")).thenReturn(user);
    }
    private Ingredient ingredient(long id) { var i=new Ingredient();i.setId(id);i.setName("Ingredient "+id);i.setUnit("g");return i; }
    private RecipeIngredient line(long id,String qty,String unit) {
        var l=new RecipeIngredient();l.setIngredient(ingredient(id));l.setQuantity(qty==null?null:new BigDecimal(qty));l.setUnit(unit);return l;
    }
    private PantryItem item(long id,String qty,String unit) {
        var p=new PantryItem();p.setIngredient(ingredient(id));p.setQuantity(qty==null?null:new BigDecimal(qty));p.setUnit(unit);return p;
    }
    private Recipe recipe(long id,String name,RecipeIngredient... lines) {
        var r=new Recipe();r.setId(id);r.setName(name);r.setServings(4);r.setIngredients(Arrays.asList(lines));return r;
    }
    private RecipeMatch one(Recipe r,PantryItem... items) {
        when(recipes.getReadableRecipeEntities(user)).thenReturn(List.of(r));
        when(pantry.findForUser(1L)).thenReturn(Arrays.asList(items));
        return service.match("a@example.test").matches().getFirst();
    }
    @ParameterizedTest @CsvSource({"500,g,500,g", "500,g,1,kg", "500,mL,1,L", "3,piece,5,piece", "2,cup,3,CUP", "2,clove,3,CLOVE"})
    void equalityGreaterAndSafeUnits(String need,String needUnit,String have,String haveUnit) {
        var m=one(recipe(1,"Recipe",line(1,need,needUnit)),item(1,have,haveUnit));
        assertEquals(MatchStatus.READY_TO_COOK,m.status());assertEquals(IngredientStatus.ENOUGH,m.ingredients().getFirst().status());
        assertEquals(new BigDecimal("100.00"),m.score());assertEquals(4,m.servings());
        assertNull(m.ingredients().getFirst().shortage());
    }
    @ParameterizedTest @CsvSource({"500,g,300,g,200,60.00", "1,kg,750,g,250,75.00", "5,piece,3,piece,2,60.00", "0.3,g,0.1,g,0.2,33.33", "0.000000000005,g,0.000000000003,g,0.000000000002,60.00"})
    void shortagesRemainExactAndCreditIsProportional(String need,String unit,String have,String haveUnit,String shortage,String score) {
        var m=one(recipe(1,"Recipe",line(1,need,unit)),item(1,have,haveUnit));
        assertEquals(MatchStatus.ALMOST_THERE,m.status());var d=m.ingredients().getFirst();
        assertEquals(IngredientStatus.SHORTAGE,d.status());assertEquals(shortage,d.shortage().quantity());
        assertEquals(new BigDecimal(score),m.score());
    }
    @Test void coreExampleExplainsAllStatesAndDoesNotMutateInputs() {
        var r=recipe(1,"Core",line(1,"500","g"),line(2,"250","g"),line(3,"2","piece"),line(4,"50","mL"));
        var rice=item(1,"300","g");var onion=item(3,null,null);
        var m=one(r,rice,item(2,"500","g"),onion,item(4,"100","mL"));
        assertEquals(MatchStatus.ALMOST_THERE,m.status());assertEquals(new BigDecimal("90.00"),m.score());
        assertEquals(new Counts(2,1,1,0,0),m.counts());assertEquals("200",m.ingredients().getFirst().shortage().quantity());
        assertEquals(new BigDecimal("300"),rice.getQuantity());assertNull(onion.getQuantity());assertEquals(4,r.getServings());
        verify(pantry).findForUser(1L);verifyNoMoreInteractions(pantry);
        verify(recipes).getReadableRecipeEntities(user);verifyNoMoreInteractions(recipes);
    }
    @Test void unknownIsLikelyWithFullCreditAndNoInventedAvailableAmount() {
        var m=one(recipe(1,"Recipe",line(1,"3","piece")),item(1,null,null));
        assertEquals(MatchStatus.LIKELY_READY,m.status());assertEquals(new BigDecimal("100.00"),m.score());
        assertEquals(IngredientStatus.PRESENT_QUANTITY_UNKNOWN,m.ingredients().getFirst().status());
        assertNull(m.ingredients().getFirst().available());assertNull(m.ingredients().getFirst().shortage());
    }
    @ParameterizedTest @CsvSource({"g,cup", "g,tbsp", "g,piece", "mL,g", "piece,pieces", "cup,tbsp"})
    void incompatibleAmountsAreUncertainNeverConverted(String needUnit,String haveUnit) {
        var m=one(recipe(1,"Recipe",line(1,"500",needUnit)),item(1,"2",haveUnit));
        assertEquals(MatchStatus.LIKELY_READY,m.status());assertEquals(new BigDecimal("50.00"),m.score());
        assertEquals(IngredientStatus.PRESENT_INCOMPARABLE,m.ingredients().getFirst().status());assertNull(m.ingredients().getFirst().shortage());
    }
    @Test void identityUsesIdsAndThreeDefiniteProblemsNeedMoreShopping() {
        var m=one(recipe(1,"Recipe",line(1,"1","g"),line(2,"1","g"),line(3,"1","g")),item(4,"100","g"));
        assertEquals(MatchStatus.MORE_SHOPPING_NEEDED,m.status());assertEquals(new Counts(0,0,0,0,3),m.counts());assertEquals(new BigDecimal("0.00"),m.score());
        // Even identical display names cannot substitute for an ID.
        var wrong=item(2,"500","g");wrong.getIngredient().setName("Ingredient 1");
        assertEquals(IngredientStatus.MISSING,one(recipe(1,"Recipe",line(1,"1","g")),wrong).ingredients().getFirst().status());
    }
    @Test void twoProblemsRemainAlmostAndUncertaintyIsNotCountedAsShortage() {
        var m=one(recipe(1,"Recipe",line(1,"1","g"),line(2,"1","g"),line(3,"1","g"),line(4,"1","g")),item(3,null,null),item(4,"1","cup"));
        assertEquals(MatchStatus.ALMOST_THERE,m.status());assertEquals(new BigDecimal("37.50"),m.score());assertEquals(new Counts(0,0,1,1,2),m.counts());
    }
    @Test void malformedRecipesAreExcludedAndEmptyPantryIsExplicit() {
        var empty=recipe(1,"Empty");var zero=recipe(2,"Zero",line(1,"0","g"));
        var invalid=recipe(3,"Blank",line(1,"1"," "));
        var duplicate=recipe(4,"Duplicate",line(1,"1","g"),line(1,"1","g"));
        var servings=recipe(5,"Servings",line(1,"1","g"));servings.setServings(0);
        var nullQuantity=recipe(6,"Null quantity",line(1,null,"g"));
        when(recipes.getReadableRecipeEntities(user)).thenReturn(List.of(empty,zero,invalid,duplicate,servings,nullQuantity));
        when(pantry.findForUser(1L)).thenReturn(List.of(item(1,"10","g")));
        var result=service.match("a@example.test");assertEquals(6,result.excludedRecipeCount());assertTrue(result.matches().isEmpty());assertFalse(result.pantryEmpty());
        when(pantry.findForUser(1L)).thenReturn(List.of());
        result=service.match("a@example.test");assertTrue(result.pantryEmpty());assertTrue(result.matches().isEmpty());
        when(recipes.getReadableRecipeEntities(user)).thenReturn(List.of());
        result=service.match("a@example.test");assertEquals(0,result.readableRecipeCount());
    }
    @Test void rankingUsesStatusThenScoreThenCaseInsensitiveNameAndId() {
        var readyB=recipe(3,"beta",line(1,"1","g"));var readyA=recipe(2,"Alpha",line(1,"1","g"));var readyAFirst=recipe(1,"alpha",line(1,"1","g"));
        var likely=recipe(4,"likely",line(2,"1","g"));var almostHigh=recipe(6,"Zed",line(3,"10","g"));
        var almostLow=recipe(5,"Aardvark",line(3,"20","g"));var shopping=recipe(7,"Shop",line(4,"1","g"),line(5,"1","g"),line(6,"1","g"));
        when(recipes.getReadableRecipeEntities(user)).thenReturn(List.of(shopping,almostLow,likely,readyB,almostHigh,readyA,readyAFirst));
        when(pantry.findForUser(1L)).thenReturn(List.of(item(1,"1","g"),item(2,null,null),item(3,"5","g")));
        assertEquals(List.of(1L,2L,3L,4L,6L,5L,7L),service.match("a@example.test").matches().stream().map(RecipeMatch::id).toList());
    }
    @Test void eachJwtIdentityLoadsItsOwnPantryOnceAndLegacyNullUnitUsesExistingFallback() {
        var b=new User();b.setId(2L);when(users.getUserByEmail("b@example.test")).thenReturn(b);
        var r=recipe(1,"Legacy",line(1,"500",null));
        when(recipes.getReadableRecipeEntities(user)).thenReturn(List.of(r));when(recipes.getReadableRecipeEntities(b)).thenReturn(List.of(r));
        when(pantry.findForUser(1L)).thenReturn(List.of(item(1,"1000","g")));
        when(pantry.findForUser(2L)).thenReturn(List.of(item(1,"300","g")));
        assertEquals(MatchStatus.READY_TO_COOK,service.match("a@example.test").matches().getFirst().status());
        assertEquals(MatchStatus.ALMOST_THERE,service.match("b@example.test").matches().getFirst().status());
        verify(pantry,times(1)).findForUser(1L);verify(pantry,times(1)).findForUser(2L);verifyNoMoreInteractions(pantry);
    }
    @Test void browseThresholdIsInclusiveAndUsesUnroundedFractions() {
        var below=recipe(1,"Below",line(1,"100000","g"));
        var equal=recipe(2,"Exactly half",line(2,"100","g"));
        var above=recipe(3,"Above",line(3,"100","g"));
        var list=List.of(below,equal,above);
        var inventory=List.of(item(1,"49999","g"),item(2,"50","g"),item(3,"51","g"));
        var all=service.matchRecipes(list,inventory,Map.of());
        assertEquals(3,all.matches().size());
        assertEquals(new BigDecimal("50.00"),all.matches().stream().filter(m->m.id()==1).findFirst().orElseThrow().score());
        var browse=service.matchRecipes(list,inventory,Map.of(),true);
        assertEquals(List.of(3L,2L),browse.matches().stream().map(RecipeMatch::id).toList());
        assertEquals(3,browse.readableRecipeCount());assertEquals(0,browse.excludedRecipeCount());
    }
    @Test void staplesAreAvailableWithoutPantryEntries() {
        for (String name : List.of("Water", "Drinking water", " salt ", "Olive oil, plain", "Black pepper, ground", "Vegetable oil")) {
            var staple=line(2,"1","g");staple.getIngredient().setName(name);
            var m=one(recipe(1,"Staple",staple),item(99,null,null));
            assertEquals(new BigDecimal("100.00"),m.score());
            assertEquals(IngredientStatus.ENOUGH,m.ingredients().getFirst().status());
            assertTrue(m.ingredients().getFirst().assumedStaple());
            assertEquals(MatchStatus.LIKELY_READY,m.status());
        }
    }
    @Test void presenceOnlyAndStaplesReachHalfThreshold() {
        var water=line(3,"1","g");water.getIngredient().setName("Water");
        var r=recipe(1,"Demo",line(1,"1","g"),line(2,"1","g"),water,line(4,"1","g"));
        var result=service.matchRecipes(List.of(r),List.of(item(1,null,null)),Map.of(),true);
        assertEquals(1,result.matches().size());
        assertEquals(new BigDecimal("50.00"),result.matches().getFirst().score());
    }
    @Test void fullUnknownCreditRemainsExplicitlyUncertainInBrowse() {
        var result=service.matchRecipes(List.of(recipe(1,"Uncertain",line(1,"1","g"))),List.of(item(1,null,null)),Map.of(),true);
        assertEquals(1,result.matches().size());
        assertEquals(IngredientStatus.PRESENT_QUANTITY_UNKNOWN,result.matches().getFirst().ingredients().getFirst().status());
    }
    @Test void fourPresenceOnlyIngredientsOutOfSevenStayVisibleInBrowse() {
        var r=recipe(1,"Kousa Mahshi",line(1,"1","g"),line(2,"1","g"),line(3,"1","g"),
                line(4,"1","g"),line(5,"1","g"),line(6,"1","g"),line(7,"1","g"));
        var result=service.matchRecipes(List.of(r),List.of(item(1,null,null),item(2,null,null),
                item(3,null,null),item(4,null,null)),Map.of(),true);
        assertEquals(1,result.matches().size());
        assertEquals(new BigDecimal("57.14"),result.matches().getFirst().score());
    }
    @Test void stapleNamesNeverMatchOtherFoodsBySubstring() {
        for (String name : List.of("Salted butter", "Olive oil dressing", "Watermelon")) {
            var food=line(2,"1","g");food.getIngredient().setName(name);
            assertEquals(IngredientStatus.MISSING,
                    one(recipe(1,"Other food",food),item(99,null,null)).ingredients().getFirst().status());
        }
    }}
