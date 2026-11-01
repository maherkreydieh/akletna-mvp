package com.akletna.backend.repository;
import com.akletna.backend.entity.IngredientClassification;
import org.springframework.data.jpa.repository.*;
import java.util.*;
public interface IngredientClassificationRepository extends JpaRepository<IngredientClassification,Long> {
    @Query("select distinct c from IngredientClassification c left join fetch c.allergens where c.ingredientId in :ids")
    List<IngredientClassification> findForIngredients(Collection<Long> ids);
}
