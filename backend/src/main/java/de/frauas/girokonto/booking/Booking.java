package de.frauas.girokonto.booking;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

// Eine Geldbewegung. Besteht aus mindestens zwei Zeilen (BookingLine), deren Summe 0 ist.
@Entity
@Table(name = "booking")
public class Booking {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private BookingType type;

    @Column(nullable = false, length = 140)
    private String description;

    // Simulationszeit, kommt aus der Clock
    @Column(name = "booked_at", nullable = false, updatable = false)
    private Instant bookedAt;

    // gleiche Anfrage = gleiche Buchung
    @Column(name = "idempotency_key", nullable = false, unique = true, length = 100, updatable = false)
    private String idempotencyKey;

    // null bei automatischen Buchungen (z. B. Startguthaben)
    @Column(name = "created_by", updatable = false)
    private Long createdBy;

    // Zeilen werden mit der Buchung zusammen gespeichert
    @OneToMany(mappedBy = "booking", cascade = CascadeType.ALL)
    @OrderBy("id")
    private List<BookingLine> lines = new ArrayList<>();

    protected Booking() {
        // für JPA
    }

    public Booking(BookingType type, String description, Instant bookedAt, String idempotencyKey, Long createdBy) {
        this.type = type;
        this.description = description;
        this.bookedAt = bookedAt;
        this.idempotencyKey = idempotencyKey;
        this.createdBy = createdBy;
    }

    public BookingLine addLine(Long accountId, long amountCents, String category) {
        BookingLine line = new BookingLine(this, accountId, amountCents, category);
        lines.add(line);
        return line;
    }

    public Long getId() { return id; }
    public BookingType getType() { return type; }
    public String getDescription() { return description; }
    public Instant getBookedAt() { return bookedAt; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public Long getCreatedBy() { return createdBy; }
    public List<BookingLine> getLines() { return Collections.unmodifiableList(lines); }
}
