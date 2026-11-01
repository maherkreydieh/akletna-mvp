package com.akletna.backend.controller;

import com.akletna.backend.dto.PreferencesRequest;
import com.akletna.backend.dto.PreferencesResponse;
import com.akletna.backend.service.UserPreferenceService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/preferences")
public class UserPreferenceController {

    private final UserPreferenceService userPreferenceService;

    public UserPreferenceController(UserPreferenceService userPreferenceService) {
        this.userPreferenceService = userPreferenceService;
    }

    @GetMapping
    public ResponseEntity<PreferencesResponse> getPreferences(Authentication authentication) {
        String userEmail = authentication.getName();
        PreferencesResponse response = userPreferenceService.getUserPreferences(userEmail);
        return ResponseEntity.ok(response);
    }

    @PutMapping
    public ResponseEntity<PreferencesResponse> updatePreferences(
            @jakarta.validation.Valid @RequestBody PreferencesRequest request,
            Authentication authentication) {
        String userEmail = authentication.getName();
        PreferencesResponse response = userPreferenceService.updateUserPreferences(request, userEmail);
        return ResponseEntity.ok(response);
    }
}
