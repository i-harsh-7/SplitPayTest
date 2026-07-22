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
import java.util.ArrayList;
import java.util.List;

/**
 * Mirrors the Mongoose Group schema (models/Group.js).
 *
 * <p>{@code members} and {@code createdBy} hold User id strings (Mongo ObjectId references).
 * Population into full user objects is done at the controller/mapper layer to match the
 * Mongoose {@code .populate("members", "name email")} behaviour.
 */
@Document(collection = "groups")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Group {

    @Id
    private String id;

    private String name;

    @Builder.Default
    private List<String> members = new ArrayList<>();

    private String createdBy;

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;
}
