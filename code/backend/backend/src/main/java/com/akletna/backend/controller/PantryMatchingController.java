package com.akletna.backend.controller;

import com.akletna.backend.dto.PantryMatchesResponse;
import com.akletna.backend.service.PantryMatchingService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/recipes/pantry-matches")
public class PantryMatchingController {
    private final PantryMatchingService matching;
    public PantryMatchingController(PantryMatchingService matching) { this.matching=matching; }
    @GetMapping
    public PantryMatchesResponse matches(Authentication authentication,
            @RequestParam(defaultValue="false") boolean minimumHalf) {
        return minimumHalf ? matching.match(authentication.getName(), true) : matching.match(authentication.getName());
    }
}
