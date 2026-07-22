package com.splitpay.service;

import com.splitpay.exception.ApiException;
import com.splitpay.model.Notification;
import com.splitpay.repository.NotificationRepository;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.List;

/**
 * Notifications feature. Backs the {@code /notifications} endpoints the Flutter client calls
 * (which had no server-side implementation in the original Node service). Notifications are
 * created as side effects of invite accept/reject so a sender learns the outcome.
 */
@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;

    public NotificationService(NotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    /** Records a notification; failures are swallowed so they never break the triggering action. */
    public void create(String recipient, String type, String title, String message,
                       String relatedUser, String relatedGroup) {
        if (!StringUtils.hasText(recipient)) {
            return;
        }
        try {
            notificationRepository.save(Notification.builder()
                    .recipient(recipient)
                    .type(type)
                    .title(title)
                    .message(message)
                    .relatedUser(relatedUser)
                    .relatedGroup(relatedGroup)
                    .build());
        } catch (Exception ignored) {
            // A notification is best-effort; never fail the parent operation because of it.
        }
    }

    public List<Notification> getForUser(String userId) {
        return notificationRepository.findByRecipientOrderByCreatedAtDesc(userId);
    }

    public void dismiss(String notificationId, String userId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> ApiException.notFound("Notification not found"));
        if (!userId.equals(n.getRecipient())) {
            throw ApiException.forbidden("not authorized");
        }
        notificationRepository.deleteById(notificationId);
    }

    public void markAsRead(String notificationId, String userId) {
        Notification n = notificationRepository.findById(notificationId)
                .orElseThrow(() -> ApiException.notFound("Notification not found"));
        if (!userId.equals(n.getRecipient())) {
            throw ApiException.forbidden("not authorized");
        }
        n.setRead(true);
        notificationRepository.save(n);
    }

    public void markAllAsRead(String userId) {
        List<Notification> unread = notificationRepository.findByRecipientAndRead(userId, false);
        for (Notification n : unread) {
            n.setRead(true);
        }
        notificationRepository.saveAll(unread);
    }
}
