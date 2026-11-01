package com.akletna.backend;

import com.akletna.backend.nutrition.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.*;
import com.akletna.backend.service.NutritionMappingService;
import com.akletna.backend.controller.NutritionMappingController;
import com.akletna.backend.exception.UnauthorizedResourceException;
import org.junit.jupiter.api.Test;
import java.net.http.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class UsdaNutritionTests {
    // Synthetic USDA-shaped fixtures only: no production nutrient data.
    private final UsdaFoodClient client = new UsdaFoodClient("", mock(HttpClient.class));
    private static final String FOOD = "\"fdcId\":123,\"description\":\"Chicken, raw\",\"dataType\":\"SR Legacy\"";
    private static String nutrient(int id, String unit, String amount) {
        return "{\"nutrient\":{\"id\":"+id+",\"unitName\":\""+unit+"\"},\"amount\":"+amount+"}";
    }
    private static String profile(String energy) {
        return "{"+FOOD+",\"foodNutrients\":["+energy+","+nutrient(1003,"g","10.125")+","+
                nutrient(1005,"g","20")+","+nutrient(1004,"g","3")+"]}";
    }
    @Test void searchPreservesDescriptionStateAndIdentityAndAllowsEmptyResults() {
        var results = client.parseSearch("{\"foods\":[{"+FOOD+"}]}");
        assertEquals("Chicken, raw", results.getFirst().description());
        assertEquals("123", results.getFirst().externalFoodId());
        assertEquals("USDA_FDC", results.getFirst().provider());
        assertTrue(client.parseSearch("{\"foods\":[]}").isEmpty());
        assertThrows(ProviderUnavailableException.class, () -> client.parseSearch("{}"));
    }
    @Test void fullDetailValuesArePer100GramsWithoutServingRescaling() {
        var p = client.parseProfile(profile(nutrient(1008,"KCAL","120.25")));
        assertEquals("120.25", p.nutrients().caloriesKcal().toPlainString());
        assertEquals("10.125", p.nutrients().proteinGrams().toPlainString());
        assertEquals("20", p.nutrients().carbohydratesGrams().toPlainString());
        assertEquals("3", p.nutrients().fatGrams().toPlainString());
    }
    @Test void prefersSpecificAtwaterEnergyAndDoesNotConfuseKjOrMg() {
        var p = client.parseProfile(profile(nutrient(1008,"kcal","120")+","+nutrient(2048,"kcal","121")));
        assertEquals("121", p.nutrients().caloriesKcal().toPlainString());
        assertThrows(ProviderUnavailableException.class, () -> client.parseProfile(profile(nutrient(1008,"kJ","500"))));
        assertThrows(ProviderUnavailableException.class, () -> client.parseProfile(profile(nutrient(1008,"kcal","120")).replace("\"g\"","\"mg\"")));
    }
    @Test void missingNegativeDuplicateMalformedAndBrandedDataAreRejected() {
        for (var body : List.of("{}", profile(nutrient(1008,"kcal","null")),
                profile(nutrient(1008,"kcal","-1")), profile(nutrient(1008,"kcal","120")).replace("SR Legacy","Branded"),
                profile(nutrient(1008,"kcal","120")).replace("1003","9999"),
                profile(nutrient(1008,"kcal","120")+","+nutrient(1008,"kcal","121"))))
            assertThrows(ProviderUnavailableException.class, () -> client.parseProfile(body));
    }
    @Test void unconfiguredKeyAndRemoteErrorsAreSafe() throws Exception {
        assertThrows(ProviderUnavailableException.class, () -> client.search("chicken"));
        var http = mock(HttpClient.class); var response = mock(HttpResponse.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(response);
        var configured = new UsdaFoodClient("synthetic-test-key", http);
        for (int code : List.of(401,403,404,429,500,502,503)) {
            when(response.statusCode()).thenReturn(code);
            assertEquals("Nutrition provider is unavailable. Try again later.",
                    assertThrows(ProviderUnavailableException.class, () -> configured.fetch("123")).getMessage());
        }
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenThrow(new java.io.IOException("private remote detail"));
        assertThrows(ProviderUnavailableException.class, () -> configured.search("rice"));
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenThrow(new java.net.http.HttpTimeoutException("remote timeout"));
        assertThrows(ProviderUnavailableException.class, () -> configured.fetch("123"));
    }

    @Test void exponentCannotBypassDatabasePrecisionLimit() {
        assertThrows(ProviderUnavailableException.class,
                () -> client.parseProfile(profile(nutrient(1008,"kcal","1e1000"))));
    }
    @Test void successfulHttpSearchAndFetchUseDocumentedContractAndSecretHeader() throws Exception {
        var http = mock(HttpClient.class);
        @SuppressWarnings("unchecked") HttpResponse<String> response = mock(HttpResponse.class);
        @SuppressWarnings("unchecked") HttpResponse<String> detail = mock(HttpResponse.class);
        when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(response, detail);
        when(response.statusCode()).thenReturn(200); when(detail.statusCode()).thenReturn(200);
        when(response.body()).thenReturn("{\"foods\":[{"+FOOD+"}]}");
        when(detail.body()).thenReturn(profile(nutrient(1008,"kcal","120.123456789012")));
        var configured = new UsdaFoodClient("synthetic-test-key",http);
        assertEquals("123", configured.search("chicken breast").getFirst().externalFoodId());
        assertEquals("120.123456789012", configured.fetch("123").nutrients().caloriesKcal().toPlainString());
        var requests = org.mockito.ArgumentCaptor.forClass(HttpRequest.class);
        verify(http,times(2)).send(requests.capture(),any(HttpResponse.BodyHandler.class));
        assertTrue(requests.getAllValues().getFirst().uri().toString().contains("dataType=Foundation,SR%20Legacy"));
        assertEquals("synthetic-test-key",requests.getAllValues().getFirst().headers().firstValue("X-Api-Key").orElseThrow());
        assertFalse(requests.getAllValues().getFirst().uri().toString().contains("synthetic-test-key"));
        assertEquals("/fdc/v1/food/123", requests.getAllValues().getLast().uri().getPath());
        assertEquals("format=full",requests.getAllValues().getLast().uri().getQuery());
    }
    @Test void reviewedMappingPersistsSourceAndCacheAndFailedRefreshPreservesOldData() {
        var ingredients = mock(IngredientRepository.class); var profiles = mock(IngredientNutritionRepository.class);
        var remote = mock(UsdaFoodClient.class); var ingredient = new Ingredient(); ingredient.setId(7L);
        when(ingredients.findById(7L)).thenReturn(Optional.of(ingredient));
        when(profiles.save(any())).thenAnswer(i -> i.getArgument(0));
        when(remote.fetch("123")).thenReturn(client.parseProfile(profile(nutrient(1008,"kcal","120"))));
        var service = new NutritionMappingService(ingredients, profiles, remote);
        var stored = service.map(7L,"123","raw");
        assertEquals("USDA_FDC", ingredient.getNutritionProvider()); assertNotNull(stored.getFetchedAt());
        when(profiles.findFirstByProviderAndExternalFoodIdAndPreparationStateOrderByFetchedAtDesc("USDA_FDC","123","raw")).thenReturn(Optional.of(stored));
        assertEquals(stored.nutrients(), new StoredNutritionProvider(profiles).per100Grams(new FoodIdentity("USDA_FDC","123","raw")).orElseThrow());
        when(remote.fetch("456")).thenThrow(new ProviderUnavailableException());
        assertThrows(ProviderUnavailableException.class, () -> service.map(7L,"456","cooked"));
        assertEquals("123", ingredient.getExternalFoodId()); assertEquals("raw", ingredient.getPreparationState());
        verify(profiles, times(1)).save(any());
    }
    @Test void ordinaryUsersAndDisabledCurationCannotModifyOrSearchTrustedData() {
        var remote = mock(UsdaFoodClient.class); var service = mock(NutritionMappingService.class);
        var controller = new NutritionMappingController(remote,service,"a".repeat(32));
        assertThrows(UnauthorizedResourceException.class, () -> controller.search(null,"rice"));
        assertThrows(UnauthorizedResourceException.class, () -> controller.map("wrong",7L,new NutritionMappingController.MappingRequest("123","raw",true)));
        assertThrows(UnauthorizedResourceException.class, () -> new NutritionMappingController(remote,service,"").search("","rice"));
        verifyNoInteractions(remote,service);
    }
    @Test void successfulRefreshUpdatesExistingProfileInsteadOfReplacingItsAssignedIdentity() {
        var ingredients = mock(IngredientRepository.class); var profiles = mock(IngredientNutritionRepository.class);
        var remote = mock(UsdaFoodClient.class); var ingredient = new Ingredient(); ingredient.setId(7L);
        var original = client.parseProfile(profile(nutrient(1008,"kcal","120")));
        var stored = new IngredientNutrition(ingredient, original, "raw");
        var refreshed = client.parseProfile(profile(nutrient(1008,"kcal","121")));
        when(ingredients.findById(7L)).thenReturn(Optional.of(ingredient));
        when(profiles.findById(7L)).thenReturn(Optional.of(stored));
        when(profiles.save(any())).thenAnswer(i -> i.getArgument(0));
        when(remote.fetch("123")).thenReturn(refreshed);
        var result = new NutritionMappingService(ingredients,profiles,remote).map(7L,"123","raw");
        assertSame(stored,result); assertEquals(7L,result.getId());
        assertEquals(refreshed.nutrients(),result.nutrients());
        verify(profiles).save(stored);
    }
}
