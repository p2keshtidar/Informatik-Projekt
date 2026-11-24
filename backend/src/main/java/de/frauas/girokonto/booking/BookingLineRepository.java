package de.frauas.girokonto.booking;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BookingLineRepository extends JpaRepository<BookingLine, Long> {

    // alle Zeilen eines Kontos (Umsätze)
    List<BookingLine> findByAccountId(Long accountId);

    // alle Zeilen einer Buchung
    List<BookingLine> findByBookingId(Long bookingId);
}
