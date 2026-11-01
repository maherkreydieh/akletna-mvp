package com.akletna.backend.controller;
import com.akletna.backend.dto.RecommendationsResponse;
import com.akletna.backend.entity.*;
import com.akletna.backend.service.RecommendationService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.Set;

@RestController
@RequestMapping("/api/recipes/recommendations")
public class RecommendationController {
    private final RecommendationService recommendations;
    public RecommendationController(RecommendationService recommendations){this.recommendations=recommendations;}
    @GetMapping("/home")
    public com.akletna.backend.dto.HomeRecommendationsResponse home(Authentication authentication,
            @RequestParam(required=false) String category,
            @RequestParam(required=false,name="goal") Set<MealGoal> goals,
            @RequestParam(required=false) DietaryPreference diet) {
        return recommendations.recommendHome(authentication.getName(),category,goals,diet);
    }
    @GetMapping
    public RecommendationsResponse get(Authentication authentication,@RequestParam(required=false) String category,
            @RequestParam(required=false,name="goal") Set<MealGoal> goals,@RequestParam(required=false) DietaryPreference diet) {
        return recommendations.recommend(authentication.getName(),category,goals,diet);
    }
}
