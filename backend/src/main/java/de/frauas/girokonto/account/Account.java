package de.frauas.girokonto.account;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "account")
public class Account {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // null bei System-Konten
    @Column(name = "owner_id")
    private Long ownerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AccountType type;

    @Column(nullable = false)
    private String name;

    @Column(unique = true)
    private String iban;

    @Column(nullable = false)
    private String status = "ACTIVE";

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Account() {
        // für JPA
    }

    public Account(Long ownerId, AccountType type, String name, String iban) {
        this.ownerId = ownerId;
        this.type = type;
        this.name = name;
        this.iban = iban;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public Long getId() { return id; }
    public Long getOwnerId() { return ownerId; }
    public AccountType getType() { return type; }
    public String getName() { return name; }
    public String getIban() { return iban; }
    public String getStatus() { return status; }
    public Instant getCreatedAt() { return createdAt; }
}
