package de.frauas.girokonto.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

// Eine Zeile einer Buchung: + Eingang, − Ausgang auf genau einem Konto
@Entity
@Table(name = "booking_line")
public class BookingLine {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "booking_id", nullable = false, updatable = false)
    private Booking booking;

    @Column(name = "account_id", nullable = false, updatable = false)
    private Long accountId;

    @Column(name = "amount_cents", nullable = false, updatable = false)
    private long amountCents;

    // optional, z. B. "Lebensmittel" bei Kartenzahlungen
    @Column(length = 30)
    private String category;

    protected BookingLine() {
        // für JPA
    }

    // Anlegen nur über Booking.addLine, damit beide Seiten der Beziehung stimmen
    BookingLine(Booking booking, Long accountId, long amountCents, String category) {
        this.booking = booking;
        this.accountId = accountId;
        this.amountCents = amountCents;
        this.category = category;
    }

    public Long getId() { return id; }
    public Booking getBooking() { return booking; }
    public Long getAccountId() { return accountId; }
    public long getAmountCents() { return amountCents; }
    public String getCategory() { return category; }
}
