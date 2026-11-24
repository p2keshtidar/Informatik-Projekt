package de.frauas.girokonto.account;

import de.frauas.girokonto.booking.BookingService;
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
    private final BookingService bookingService;

    public AccountService(AccountRepository accounts, AppUserRepository users, BookingService bookingService) {
        this.accounts = accounts;
        this.users = users;
        this.bookingService = bookingService;
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

    // Startguthaben (10.000,00 €) auf ein gerade eröffnetes Girokonto, in derselben Transaktion wie die Eröffnung.
    // Der Key "opening-<userId>" verhindert, dass es doppelt gebucht wird.
    @Transactional
    public void bookStartCredit(Account mainAccount) {
        bookingService.bookStartCredit(mainAccount.getOwnerId(), mainAccount.getId());
    }

    // Prüft, dass das Konto dem Nutzer gehört: unbekannt → 404, fremdes Konto → 403.
    // Für alles, was mit einer accountId aus der URL arbeitet (Umsätze, später Überweisungen).
    @Transactional(readOnly = true)
    public Account requireOwnAccount(Long userId, Long accountId) {
        Account account = accounts.findById(accountId)
                .orElseThrow(() -> ApiException.notFound("Konto nicht gefunden"));
        if (!userId.equals(account.getOwnerId())) {
            throw ApiException.forbidden("Das ist nicht dein Konto");
        }
        return account;
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
