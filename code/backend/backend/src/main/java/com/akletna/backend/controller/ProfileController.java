package com.akletna.backend.controller;

import com.akletna.backend.dto.*;
import com.akletna.backend.service.ProfileService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me/profile")
public class ProfileController {
    private final ProfileService profiles;
    public ProfileController(ProfileService profiles) { this.profiles=profiles; }
    @GetMapping public ResponseEntity<ProfileResponse> get(Authentication auth) { return privateResponse(profiles.get(auth.getName())); }
    @PutMapping public ResponseEntity<ProfileResponse> update(Authentication auth,@Valid @RequestBody ProfileUpdateRequest request) { return privateResponse(profiles.update(auth.getName(),request)); }
    private ResponseEntity<ProfileResponse> privateResponse(ProfileResponse profile) { return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(profile); }
}
