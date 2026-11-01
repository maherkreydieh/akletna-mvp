package com.akletna.backend;

import com.akletna.backend.dto.ProfileUpdateRequest;
import com.akletna.backend.entity.User;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.repository.UserRepository;
import com.akletna.backend.service.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ProfileTests {
    private final UserService users=mock(UserService.class);
    private final UserRepository repository=mock(UserRepository.class);
    private final ProfileService service=new ProfileService(users,repository);
    private User user() {
        var user=new User();user.setId(4L);user.setName("Original");user.setEmail("owner@example.test");
        when(users.getUserByEmail(user.getEmail())).thenReturn(user);return user;
    }
    @Test void updatesOnlyAuthenticatedOwnerAndTrimsName() {
        var user=user();var result=service.update(user.getEmail(),new ProfileUpdateRequest("  New name  "));
        assertEquals("New name",result.name());assertEquals(4L,result.id());verify(repository).save(user);
    }
    @Test void invalidNameNeverChangesStoredProfile() {
        var user=user();
        for (String name : new String[]{null,"x".repeat(101),"bad\nname"})
            assertThrows(BadRequestException.class,()->service.update(user.getEmail(),new ProfileUpdateRequest(name)));
        assertEquals("Original",user.getName());verifyNoInteractions(repository);
    }
}
