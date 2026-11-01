package com.akletna.backend.repository;

import com.akletna.backend.entity.IngredientNutrition;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface IngredientNutritionRepository extends JpaRepository<IngredientNutrition, Long> {
    interface Snapshot {
        String getProvider(); String getExternalFoodId(); String getPreparationState(); java.time.Instant getFetchedAt();
        java.math.BigDecimal getCaloriesKcal(); java.math.BigDecimal getProteinGrams();
        java.math.BigDecimal getCarbohydratesGrams(); java.math.BigDecimal getFatGrams();
    }
    @org.springframework.data.jpa.repository.Query("select n.provider as provider,n.externalFoodId as externalFoodId,n.preparationState as preparationState,n.fetchedAt as fetchedAt,n.caloriesKcal as caloriesKcal,n.proteinGrams as proteinGrams,n.carbohydratesGrams as carbohydratesGrams,n.fatGrams as fatGrams from IngredientNutrition n where n.provider=:provider and n.externalFoodId in :ids order by n.fetchedAt desc")
    java.util.List<Snapshot> findSnapshots(String provider,java.util.Collection<String> ids);
    Optional<IngredientNutrition> findFirstByProviderAndExternalFoodIdAndPreparationStateOrderByFetchedAtDesc(String provider, String externalFoodId, String preparationState);
}
