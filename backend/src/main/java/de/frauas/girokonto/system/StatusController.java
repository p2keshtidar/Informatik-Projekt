package de.frauas.girokonto.system;

import de.frauas.girokonto.user.AppUserRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Instant;

@RestController
@RequestMapping("/api/status")
public class StatusController {

    private final AppUserRepository users;
    private final Clock clock;

    public StatusController(AppUserRepository users, Clock clock) {
        this.users = users;
        this.clock = clock;
    }

    @GetMapping
    public StatusDto status() {
        return new StatusDto("UP", Instant.now(clock), users.count());
    }

    public record StatusDto(String status, Instant time, long users) {
    }
}
