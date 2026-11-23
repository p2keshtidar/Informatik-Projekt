package de.frauas.girokonto.account;

import de.frauas.girokonto.auth.AuthUser;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class AccountController {

    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    // Konten des angemeldeten Nutzers. Wer das ist, steht im Access-Token, nicht in der URL.
    @GetMapping("/api/accounts")
    public List<AccountDto> accounts(@AuthenticationPrincipal AuthUser me) {
        return accountService.accountsOf(me.id());
    }
}
