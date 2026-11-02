package de.frauas.girokonto.account;

import de.frauas.girokonto.common.ApiException;
import de.frauas.girokonto.common.Iban;
import de.frauas.girokonto.user.AppUser;
import de.frauas.girokonto.user.AppUserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AccountService {

    private final AccountRepository accounts;
    private final AppUserRepository users;

    public AccountService(AccountRepository accounts, AppUserRepository users) {
        this.accounts = accounts;
        this.users = users;
    }

    // Jeder Nutzer bekommt genau ein Girokonto
    @Transactional
    public Account openMainAccount(AppUser user) {
        if (accounts.existsByOwnerIdAndType(user.getId(), AccountType.MAIN)) {
            throw ApiException.conflict("Es gibt schon ein Girokonto");
        }
        String iban = Iban.forAccountNumber(accounts.nextAccountNumber());
        return accounts.save(new Account(user.getId(), AccountType.MAIN, "Girokonto", iban));
    }

    @Transactional(readOnly = true)
    public boolean hasMainAccount(Long userId) {
        return accounts.existsByOwnerIdAndType(userId, AccountType.MAIN);
    }

    @Transactional(readOnly = true)
    public List<AccountDto> accountsOf(Long userId) {
        if (!users.existsById(userId)) {
            throw ApiException.notFound("Nutzer nicht gefunden");
        }
        return accounts.findByOwnerIdOrderById(userId).stream()
                .map(a -> new AccountDto(a.getId(), a.getType(), a.getName(), a.getIban(),
                        accounts.balanceOf(a.getId())))
                .toList();
    }
}
