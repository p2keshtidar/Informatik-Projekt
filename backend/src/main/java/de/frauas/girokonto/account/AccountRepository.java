package de.frauas.girokonto.account;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface AccountRepository extends JpaRepository<Account, Long> {

    List<Account> findByOwnerIdOrderById(Long ownerId);

    boolean existsByOwnerIdAndType(Long ownerId, AccountType type);

    @Query(value = "SELECT nextval('account_number_seq')", nativeQuery = true)
    long nextAccountNumber();

    // Kontostand = Summe aller Buchungszeilen, wird nicht gespeichert
    @Query(value = "SELECT COALESCE(SUM(amount_cents), 0) FROM booking_line WHERE account_id = :accountId",
            nativeQuery = true)
    long balanceOf(@Param("accountId") Long accountId);
}
