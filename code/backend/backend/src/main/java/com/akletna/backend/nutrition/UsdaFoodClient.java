package com.akletna.backend.nutrition;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.math.BigDecimal;
import java.util.*;

/** Only Foundation and SR Legacy: full-detail foodNutrients.amount is per 100 g. */
@Component
public class UsdaFoodClient {
    public static final String PROVIDER = "USDA_FDC";
    private final String key;
    private final HttpClient http;
    private final ObjectMapper json = tools.jackson.databind.json.JsonMapper.builder()
            .enable(tools.jackson.databind.DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS).build();
    @org.springframework.beans.factory.annotation.Autowired
    public UsdaFoodClient(@Value("${akletna.nutrition.usda.api-key:}") String key) {
        this(key, HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build());
    }
    public UsdaFoodClient(String key, HttpClient http) { this.key = key; this.http = http; }
    public record Food(String provider, String externalFoodId, String description, String dataType) { }
    public record Profile(Food food, Nutrients nutrients) { }

    public List<Food> search(String query) {
        if (query == null || query.isBlank() || query.length() > 120)
            throw new com.akletna.backend.exception.BadRequestException("Search must contain 1–120 characters.");
        return parseSearch(request("/foods/search?query=" + encode(query.trim()) +
                "&pageSize=20&dataType=Foundation,SR%20Legacy"));
    }
    public Profile fetch(String id) {
        if (id == null || !id.matches("[1-9][0-9]{0,11}"))
            throw new com.akletna.backend.exception.BadRequestException("Invalid USDA food ID.");
        Profile profile = parseProfile(request("/food/" + id + "?format=full"));
        if (!profile.food.externalFoodId.equals(id)) throw new ProviderUnavailableException();
        return profile;
    }
    private String request(String path) {
        if (key == null || key.isBlank()) throw new ProviderUnavailableException();
        try {
            var req = HttpRequest.newBuilder(URI.create("https://api.nal.usda.gov/fdc/v1" + path))
                    .header("X-Api-Key", key).timeout(Duration.ofSeconds(10)).GET().build();
            var res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200 || res.body().length() > 2_000_000) throw new ProviderUnavailableException();
            return res.body();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt(); throw new ProviderUnavailableException();
        } catch (Exception e) { throw new ProviderUnavailableException(); }
    }
    private static String encode(String value) { return URLEncoder.encode(value, StandardCharsets.UTF_8); }
    private static boolean supported(String type) { return "Foundation".equals(type) || "SR Legacy".equals(type); }
    private Food food(JsonNode node) {
        String id = node.path("fdcId").asText(), description = node.path("description").asText();
        String type = node.path("dataType").asText();
        if (!id.matches("[1-9][0-9]{0,11}") || description.isBlank() || description.length() > 1000 || !supported(type))
            throw new ProviderUnavailableException();
        return new Food(PROVIDER, id, description, type);
    }
    public List<Food> parseSearch(String body) {
        try {
            var root = json.readTree(body); var foods = root.path("foods");
            if (!foods.isArray()) throw new ProviderUnavailableException();
            List<Food> result = new ArrayList<>();
            for (var node : foods) if (supported(node.path("dataType").asText())) result.add(food(node));
            return List.copyOf(result);
        } catch (Exception e) { throw new ProviderUnavailableException(); }
    }
    public Profile parseProfile(String body) {
        try {
            var root = json.readTree(body); Food food = food(root);
            Map<Integer, BigDecimal> values = new HashMap<>();
            var nutrients = root.path("foodNutrients");
            if (!nutrients.isArray()) throw new ProviderUnavailableException();
            for (var row : nutrients) {
                var nutrient = row.path("nutrient"); int id = nutrient.path("id").asInt();
                if (!Set.of(1008, 2047, 2048, 1003, 1004, 1005).contains(id)) continue;
                String unit = nutrient.path("unitName").asText();
                boolean energy = Set.of(1008, 2047, 2048).contains(id);
                if (!(energy ? "kcal" : "g").equalsIgnoreCase(unit) || !row.path("amount").isNumber())
                    throw new ProviderUnavailableException();
                BigDecimal amount = new BigDecimal(row.path("amount").asText());
                if (amount.signum() < 0 || amount.precision() > 24 || amount.scale() > 12
                        || (long)amount.precision() - amount.scale() > 12 || values.putIfAbsent(id, amount) != null)
                    throw new ProviderUnavailableException();
            }
            // Prefer food-specific Atwater energy, then general, then legacy energy. Never derive guessed energy.
            BigDecimal energy = values.get(2048);
            if (energy == null) energy = values.get(2047);
            if (energy == null) energy = values.get(1008);
            return new Profile(food, new Nutrients(energy, values.get(1003), values.get(1005), values.get(1004)));
        } catch (Exception e) { throw new ProviderUnavailableException(); }
    }
}
