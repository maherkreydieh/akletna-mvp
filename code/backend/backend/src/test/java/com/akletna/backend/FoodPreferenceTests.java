package com.akletna.backend;
import com.akletna.backend.entity.*;
import com.akletna.backend.dto.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.*;
import com.akletna.backend.exception.BadRequestException;
import org.junit.jupiter.api.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class FoodPreferenceTests {
    UserPreferenceRepository rows;UserRepository users;IngredientRepository ingredients;UserService identities;
    UserPreferenceService service;User a,b;
    @BeforeEach void setup() {
        rows=mock(UserPreferenceRepository.class);users=mock(UserRepository.class);ingredients=mock(IngredientRepository.class);identities=mock(UserService.class);
        service=new UserPreferenceService(rows,identities,users,ingredients);
        a=new User();a.setId(1L);b=new User();b.setId(2L);
        when(identities.getUserByEmail("a")).thenReturn(a);when(identities.getUserByEmail("b")).thenReturn(b);
        when(users.findLockedById(1L)).thenReturn(Optional.of(a));when(users.findLockedById(2L)).thenReturn(Optional.of(b));
        when(rows.save(any())).thenAnswer(i->i.getArgument(0));
    }
    @Test void newProfileReadDoesNotWriteAndUpdateStoresSeparateStructuredDimensions() {
        var empty=service.getUserPreferences("a");assertTrue(empty.getAllergies().isEmpty());assertNull(empty.getId());verify(rows,never()).save(any());
        var eggplant=new Ingredient();eggplant.setId(42L);eggplant.setName("Eggplant");
        when(ingredients.findAllById(Set.of(42L))).thenReturn(List.of(eggplant));
        var request=new PreferencesRequest(Set.of("Yakhnet"),Set.of("SESAME"),Set.of("vegan"),null);
        request.setDislikedIngredientIds(Set.of(42L));request.setPreferredMealGoals(Set.of(MealGoal.HIGH_PROTEIN,MealGoal.BUDGET_FRIENDLY));
        var result=service.updateUserPreferences(request,"a");
        assertEquals(Set.of("VEGAN"),result.getDietaryRestrictions());assertEquals(Set.of("SESAME"),result.getAllergies());
        assertEquals(Set.of("Yakhnet"),result.getPreferredCategories());assertEquals(Set.of(42L),result.getDislikedIngredientIds());assertEquals(2,result.getPreferredMealGoals().size());
        var capture=org.mockito.ArgumentCaptor.forClass(UserPreference.class);verify(rows).save(capture.capture());assertSame(a,capture.getValue().getUser());
        when(rows.findByUser(a)).thenReturn(Optional.of(capture.getValue()));
        assertEquals(Set.of(42L),service.getUserPreferences("a").getDislikedIngredientIds());assertTrue(service.getUserPreferences("b").getDislikedIngredientIds().isEmpty());
    }
    @Test void recognizedLegacyStringsEvolveAndUnsupportedEntriesStayVisibleWithoutNameMatching() {
        var pref=new UserPreference(a);pref.setAllergies(Set.of("Milk","sesame","legacy avoidance"));
        pref.setDietaryRestrictions(Set.of("Vegetarian","custom diet"));pref.setDislikedIngredients(Set.of("cilantro"));
        when(rows.findByUser(a)).thenReturn(Optional.of(pref));
        var result=service.getUserPreferences("a");assertEquals(Set.of("DAIRY","SESAME"),result.getAllergies());
        assertEquals(Set.of("legacy avoidance"),result.getLegacyAllergies());assertEquals(Set.of("custom diet"),result.getLegacyDietaryRestrictions());
        assertTrue(result.getDislikedIngredientIds().isEmpty());verifyNoInteractions(ingredients);
        result=service.updateUserPreferences(new PreferencesRequest(null,Set.of(),Set.of("VEGAN"),null),"a");
        assertEquals(Set.of("legacy avoidance"),pref.getAllergies());assertEquals(Set.of("VEGAN","custom diet"),pref.getDietaryRestrictions());
        assertEquals(Set.of("cilantro"),result.getDislikedIngredients());
    }
    @Test void invalidIdsUnsupportedSelectionsAndLegacyNameWritesCannotPartiallyMutateProfile() {
        var pref=new UserPreference(a);pref.setAllergies(Set.of("SESAME"));when(rows.findByUser(a)).thenReturn(Optional.of(pref));
        var bad=new PreferencesRequest(null,Set.of("invalid avoidance"),Set.of("VEGAN"),null);
        assertThrows(BadRequestException.class,()->service.updateUserPreferences(bad,"a"));
        var missing=new PreferencesRequest(null,Set.of(),Set.of("VEGAN"),null);missing.setDislikedIngredientIds(Set.of(999L));
        assertThrows(BadRequestException.class,()->service.updateUserPreferences(missing,"a"));
        assertThrows(BadRequestException.class,()->service.updateUserPreferences(new PreferencesRequest(null,null,null,Set.of("eggplant")),"a"));
        assertEquals(Set.of("SESAME"),pref.getAllergies());assertTrue(pref.getDietaryRestrictions().isEmpty());verify(rows,never()).save(any());
    }
}
