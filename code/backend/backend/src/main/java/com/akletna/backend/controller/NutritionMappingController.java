package com.akletna.backend.controller;

import com.akletna.backend.nutrition.*;
import com.akletna.backend.service.NutritionMappingService;
import com.akletna.backend.exception.UnauthorizedResourceException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;

/** MVP curator workflow: JWT plus a separate server-configured secret. Disabled by default. */
@RestController @RequestMapping("/api/nutrition/curation")
public class NutritionMappingController {
    private final UsdaFoodClient client;
    private final NutritionMappingService mappings;
    private final String curatorToken;
    public NutritionMappingController(UsdaFoodClient client, NutritionMappingService mappings,
            @Value("${akletna.nutrition.curator-token:}") String curatorToken) {
        this.client = client; this.mappings = mappings; this.curatorToken = curatorToken;
    }
    public record MappingRequest(@NotBlank @Pattern(regexp="[1-9][0-9]{0,11}") String externalFoodId,
            @NotBlank @Size(max=100) String preparationState, @AssertTrue boolean reviewed) { }
    public record MappingResponse(String provider, String externalFoodId, String description, String dataType,
            String preparationState, java.time.Instant fetchedAt, Nutrients per100Grams) { }
    private void authorize(String supplied) {
        com.akletna.backend.service.CuratorAccess.require(curatorToken,supplied);
    }
    @GetMapping("/foods")
    public List<UsdaFoodClient.Food> search(@RequestHeader(value="X-Nutrition-Curator-Token", required=false) String token,
            @RequestParam String query) { authorize(token); return client.search(query); }
    @PostMapping("/ingredients/{id}/mapping")
    public MappingResponse map(@RequestHeader(value="X-Nutrition-Curator-Token", required=false) String token,
            @PathVariable Long id, @Valid @RequestBody MappingRequest request) {
        authorize(token);
        var result = mappings.map(id, request.externalFoodId(), request.preparationState());
        return new MappingResponse(result.getProvider(), result.getExternalFoodId(), result.getDescription(), result.getDataType(),
                result.getPreparationState(), result.getFetchedAt(), result.nutrients());
    }
}
