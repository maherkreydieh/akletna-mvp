package com.akletna.backend;

import com.akletna.backend.entity.IngredientNutrition;
import com.akletna.backend.nutrition.*;
import com.akletna.backend.repository.IngredientNutritionRepository;
import org.junit.jupiter.api.Test;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class StoredNutritionValidationTests {
    @Test void invalidStoredProfileIsUnavailableAndNeverTriggersAnExternalRequest() {
        var rows=mock(IngredientNutritionRepository.class);var profile=mock(IngredientNutrition.class);
        when(rows.findFirstByProviderAndExternalFoodIdAndPreparationStateOrderByFetchedAtDesc("USDA_FDC","123","raw"))
            .thenReturn(Optional.of(profile));
        when(profile.nutrients()).thenThrow(new IllegalArgumentException("Invalid stored fixture"));
        assertTrue(new StoredNutritionProvider(rows).per100Grams(new FoodIdentity("USDA_FDC","123","raw")).isEmpty());
        verify(rows).findFirstByProviderAndExternalFoodIdAndPreparationStateOrderByFetchedAtDesc("USDA_FDC","123","raw");
        verifyNoMoreInteractions(rows);
    }
    @Test void userDeclaredProviderIsNeverTreatedAsTrustedNutrition() {
        var rows=mock(IngredientNutritionRepository.class);
        assertTrue(new StoredNutritionProvider(rows).per100Grams(new FoodIdentity("USER_PROVIDED","123","raw")).isEmpty());
        verifyNoInteractions(rows);
    }
}
