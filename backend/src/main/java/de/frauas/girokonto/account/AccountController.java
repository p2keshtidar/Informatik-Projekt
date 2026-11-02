package de.frauas.girokonto.account;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class AccountController {

    private final AccountService accountService;

    public AccountController(AccountService accountService) {
        this.accountService = accountService;
    }

    // TODO: Nutzer später aus dem JWT lesen statt aus der URL
    @GetMapping("/api/users/{userId}/accounts")
    public List<AccountDto> accounts(@PathVariable Long userId) {
        return accountService.accountsOf(userId);
    }
}
