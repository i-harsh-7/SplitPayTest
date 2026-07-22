package com.splitpay.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * Mirrors the Mongoose Invite schema (models/invite.js).
 *
 * <p>{@code status} is one of "pending" | "accepted" | "rejected", defaulting to "pending".
 */
@Document(collection = "invites")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Invite {

    @Id
    private String id;

    /** Group id reference. */
    private String group;

    /** Sender User id reference. */
    private String sender;

    /** Receiver User id reference. */
    private String receiver;

    @Builder.Default
    private String status = "pending";

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;
}
