package com.akletna.backend.service;

import com.akletna.backend.dto.PantryMatchesResponse;
import com.akletna.backend.dto.PantryMatchesResponse.*;
import com.akletna.backend.entity.*;
import com.akletna.backend.repository.PantryItemRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.*;
import static com.akletna.backend.dto.PantryMatchesResponse.IngredientStatus.*;

/** Read-only base-recipe feasibility; never consumes inventory or requests nutrition. */
@Service
public class PantryMatchingService {
    private static final Set<String> BASIC_STAPLES = Set.of(
            "water", "drinking water", "salt", "table salt", "sea salt", "salt, table",
            "black pepper", "black pepper, ground", "pepper, black",
            "olive oil", "olive oil, plain", "vegetable oil");
    private final UserService users;
    private final RecipeService recipes;
    private final PantryItemRepository pantry;
    private final RecipeEvaluationService evaluation;
    public PantryMatchingService(UserService users, RecipeService recipes, PantryItemRepository pantry,RecipeEvaluationService evaluation) {
        this.users=users; this.recipes=recipes; this.pantry=pantry;this.evaluation=evaluation;
    }
    @Transactional(readOnly=true)
    public PantryMatchesResponse match(String email) { return match(email, false); }
    @Transactional(readOnly=true)
    public PantryMatchesResponse match(String email, boolean minimumHalf) {
        var user=users.getUserByEmail(email);
        var inventory=pantry.findForUser(user.getId());
        var readable=recipes.getReadableRecipeEntities(user);
        var evaluations=inventory.isEmpty() ? java.util.Map.<Long,com.akletna.backend.dto.RecipeEvaluationResponse>of() : evaluation.evaluate(user,readable);
        return matchRecipes(readable, inventory, evaluations, minimumHalf);
    }
    /** Shared pure calculation over already-authorized, bulk-loaded inputs. */
    public PantryMatchesResponse matchRecipes(List<Recipe> readable, List<PantryItem> inventory,
            Map<Long,com.akletna.backend.dto.RecipeEvaluationResponse> evaluations) {
        return matchRecipes(readable, inventory, evaluations, false);
    }
    /** Browse threshold uses the exact score, before display rounding. */
    public PantryMatchesResponse matchRecipes(List<Recipe> readable, List<PantryItem> inventory,
            Map<Long,com.akletna.backend.dto.RecipeEvaluationResponse> evaluations, boolean minimumHalf) {
        var byIngredient=new HashMap<Long,PantryItem>();
        inventory.forEach(item -> byIngredient.put(item.getIngredient().getId(),item));
        var matches=new ArrayList<RecipeMatch>();
        int excluded=0;
        for (var recipe:readable) {
            if (!valid(recipe)) { excluded++; continue; }
            if (!inventory.isEmpty()) {
                var compared=compare(recipe,byIngredient,evaluations.get(recipe.getId()));
                if (!minimumHalf || compared.atLeastHalf()) matches.add(compared.match());
            }
        }
        matches.sort(Comparator.comparing(RecipeMatch::status)
                .thenComparing(RecipeMatch::score,Comparator.reverseOrder())
                .thenComparing(m -> m.name().toLowerCase(Locale.ROOT))
                .thenComparing(RecipeMatch::id));
        return new PantryMatchesResponse(inventory.isEmpty(),readable.size(),excluded,List.copyOf(matches));
    }
    public boolean valid(Recipe recipe) {
        if (recipe.getName()==null || recipe.getName().isBlank() || recipe.getServings()==null || recipe.getServings()<=0
                || recipe.getIngredients()==null || recipe.getIngredients().isEmpty()) return false;
        var ids=new HashSet<Long>();
        for (var line:recipe.getIngredients()) {
            if (line.getIngredient()==null || line.getIngredient().getId()==null || line.getIngredient().getName()==null ||
                    !ids.add(line.getIngredient().getId()) || line.getQuantity()==null || line.getQuantity().signum()<=0
                    || unit(line)==null || unit(line).isBlank()) return false;
        }
        return true;
    }
    // Preserve the existing legacy recipe-line fallback; an explicit blank unit is invalid.
    private String unit(RecipeIngredient line) { return line.getUnit()!=null ? line.getUnit() : line.getIngredient().getUnit(); }
    public record Comparison(IngredientStatus status, QuantityScaling.Quantity required,
            QuantityScaling.Quantity available, QuantityScaling.Quantity shortage, String unit, String availableUnit) {}
    /** Shared exact comparison for base-recipe matching and intended-serving grocery actions. */
    public Comparison compareIngredient(RecipeIngredient line, PantryItem item, int servings, int baseServings) {
        var requiredUnit=QuantityUnit.of(unit(line));
        var required=requiredUnit.canonicalQuantity(QuantityScaling.effectiveQuantity(line.getQuantity(),servings,baseServings));
        IngredientStatus state; QuantityScaling.Quantity have=null,shortage=null; String availableUnit=null;
        if (BASIC_STAPLES.contains(line.getIngredient().getName().strip().toLowerCase(Locale.ROOT))) state=ENOUGH;
        else if (item==null) state=MISSING;
        else if (item.getQuantity()==null && item.getUnit()==null) state=PRESENT_QUANTITY_UNKNOWN;
        else if (item.getQuantity()==null || item.getQuantity().signum()<=0 || item.getUnit()==null || item.getUnit().isBlank()) state=PRESENT_INCOMPARABLE;
        else {
            var inventoryUnit=QuantityUnit.of(item.getUnit()); availableUnit=inventoryUnit.canonicalUnit();
            have=inventoryUnit.canonicalQuantity(QuantityScaling.Quantity.of(item.getQuantity()));
            if (!requiredUnit.compatibleWith(inventoryUnit)) state=PRESENT_INCOMPARABLE;
            else if (have.compareTo(required)>=0) state=ENOUGH;
            else { state=SHORTAGE; shortage=required.subtract(have); }
        }
        return new Comparison(state,required,have,shortage,requiredUnit.canonicalUnit(),availableUnit);
    }
    private record ScoredMatch(RecipeMatch match, boolean atLeastHalf) {}
    private ScoredMatch compare(Recipe recipe,Map<Long,PantryItem> inventory,com.akletna.backend.dto.RecipeEvaluationResponse evaluated) {
        var details=new ArrayList<IngredientMatch>();
        var credit=new QuantityScaling.Quantity(BigInteger.ZERO,BigInteger.ONE);
        int[] counts=new int[IngredientStatus.values().length];
        var lines=recipe.getIngredients().stream().sorted(Comparator
                .comparing((RecipeIngredient l)->l.getIngredient().getName(),String.CASE_INSENSITIVE_ORDER)
                .thenComparing(l->l.getIngredient().getId())).toList();
        for (var line:lines) {
            var comparison=compareIngredient(line,inventory.get(line.getIngredient().getId()),recipe.getServings(),recipe.getServings());
            var state=comparison.status();
            Amount available=comparison.available()==null ? null : amount(comparison.available().rounded(12),comparison.availableUnit());
            Amount shortage=comparison.shortage()==null ? null : amount(comparison.shortage().rounded(12),comparison.unit());
            var contribution=new QuantityScaling.Quantity(BigInteger.ZERO,BigInteger.ONE);
            if (state==SHORTAGE) contribution=comparison.available().divide(comparison.required());
            if (state==ENOUGH || state==PRESENT_QUANTITY_UNKNOWN) contribution=new QuantityScaling.Quantity(BigInteger.ONE,BigInteger.ONE);
            if (state==PRESENT_INCOMPARABLE)
                contribution=new QuantityScaling.Quantity(BigInteger.ONE,BigInteger.TWO);
            credit=credit.add(contribution);
            counts[state.ordinal()]++;
            details.add(new IngredientMatch(line.getIngredient().getId(),line.getIngredient().getName(),state,
                    amount(comparison.required().rounded(12),comparison.unit()),available,shortage,
                    state==ENOUGH && comparison.available()==null));
        }
        int problems=counts[MISSING.ordinal()]+counts[SHORTAGE.ordinal()];
        var status=problems==0 ? (counts[ENOUGH.ordinal()]==lines.size() && details.stream().noneMatch(IngredientMatch::assumedStaple) ? MatchStatus.READY_TO_COOK : MatchStatus.LIKELY_READY)
                : problems<=2 ? MatchStatus.ALMOST_THERE : MatchStatus.MORE_SHOPPING_NEEDED;
        var score=new QuantityScaling.Quantity(credit.numerator().multiply(BigInteger.valueOf(100)),
                credit.denominator().multiply(BigInteger.valueOf(lines.size()))).rounded(2);
        boolean atLeastHalf=credit.numerator().multiply(BigInteger.TWO).compareTo(
                credit.denominator().multiply(BigInteger.valueOf(lines.size())))>=0;
        return new ScoredMatch(new RecipeMatch(recipe.getId(),recipe.getName(),recipe.getOrigin(),recipe.getVisibility(),recipe.getServings(),
                recipe.getCookingTime(),recipe.getImageUrl(),status,score,
                new Counts(counts[0],counts[1],counts[2],counts[3],counts[4]),List.copyOf(details),evaluated),atLeastHalf);
    }
    private static Amount amount(BigDecimal quantity,String unit) { return new Amount(quantity.stripTrailingZeros().toPlainString(),unit); }
}
