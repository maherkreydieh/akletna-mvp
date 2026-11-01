package com.akletna.backend.repository;

import com.akletna.backend.entity.*;
import org.springframework.data.jpa.repository.*;
import java.util.List;

public interface GroceryContributionRepository extends JpaRepository<GroceryContribution,Long> {
    @EntityGraph(attributePaths="lines")
    List<GroceryContribution> findByGroceryListOrderByIdAsc(GroceryList list);
}
