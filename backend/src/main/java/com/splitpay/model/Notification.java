package com.splitpay.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * A user-facing notification (e.g. "X accepted your invite to Group Y").
 *
 * <p>There was no Notification collection in the original Node service — the Flutter client calls
 * {@code /notifications} endpoints that never existed. This model backs those endpoints. The
 * {@code type} mirrors what the client parses: {@code invite_accepted}, {@code invite_rejected},
 * or a generic {@code info}.
 */
@Document(collection = "notifications")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Notification {

    @Id
    private String id;

    /** The user who should see this notification (User id reference). */
    @Indexed
    private String recipient;

    /** invite_accepted | invite_rejected | info */
    @Builder.Default
    private String type = "info";

    private String title;

    private String message;

    /** Optional related entities, stored as id strings for context. */
    private String relatedUser;
    private String relatedGroup;

    @Builder.Default
    private boolean read = false;

    @CreatedDate
    private Instant createdAt;
}
