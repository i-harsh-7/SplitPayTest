package com.splitpay.repository;

import com.splitpay.model.Notification;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface NotificationRepository extends MongoRepository<Notification, String> {

    /** A user's notifications, newest first. */
    List<Notification> findByRecipientOrderByCreatedAtDesc(String recipient);

    List<Notification> findByRecipientAndRead(String recipient, boolean read);
}
