package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.User;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProfileService {
    private final UserService users;
    private final UserRepository repository;
    public ProfileService(UserService users, UserRepository repository) {
        this.users = users;
        this.repository = repository;
    }
    public ProfileResponse get(String email) { return response(users.getUserByEmail(email)); }
    @Transactional
    public ProfileResponse update(String email, ProfileUpdateRequest request) {
        if (request.name() == null || request.name().length() > 100
                || request.name().codePoints().anyMatch(Character::isISOControl))
            throw new BadRequestException("Use a display name of at most 100 characters.");
        User user = users.getUserByEmail(email);
        user.setName(request.name().strip());
        repository.save(user);
        return response(user);
    }
    private ProfileResponse response(User user) {
        return new ProfileResponse(user.getId(), user.getName(), user.getEmail());
    }
}
