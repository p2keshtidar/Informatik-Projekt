package de.frauas.girokonto.mail;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface MailCodeRepository extends JpaRepository<MailCode, Long> {

    // neuester noch offener Code, gesperrt bis zum Ende der Transaktion
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<MailCode> findFirstByUserIdAndPurposeAndUsedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(
            Long userId, MailPurpose purpose, Instant now);

    boolean existsByUserIdAndPurposeAndUsedAtIsNullAndCreatedAtAfter(
            Long userId, MailPurpose purpose, Instant since);

    @Modifying
    @Query("UPDATE MailCode c SET c.usedAt = :now "
            + "WHERE c.userId = :userId AND c.purpose = :purpose AND c.usedAt IS NULL")
    void invalidateOpen(@Param("userId") Long userId, @Param("purpose") MailPurpose purpose,
                        @Param("now") Instant now);
}
