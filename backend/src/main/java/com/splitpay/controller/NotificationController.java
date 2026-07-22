package com.splitpay.controller;

import com.splitpay.model.Notification;
import com.splitpay.security.CurrentUser;
import com.splitpay.service.NotificationService;
import com.splitpay.service.ResponseMapper;
import com.splitpay.web.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Notification endpoints under /api/v1/notifications, matching what the Flutter
 * {@code NotificationService} client calls.
 */
@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;
    private final ResponseMapper responseMapper;

    public NotificationController(NotificationService notificationService, ResponseMapper responseMapper) {
        this.notificationService = notificationService;
        this.responseMapper = responseMapper;
    }

    @GetMapping
    public ResponseEntity<?> getNotifications() {
        List<Notification> notifications = notificationService.getForUser(CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Notifications fetched successfully")
                .with("notifications", responseMapper.populateNotifications(notifications))
                .with("count", notifications.size()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> dismiss(@PathVariable String id) {
        notificationService.dismiss(id, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Notification dismissed"));
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<?> markAsRead(@PathVariable String id) {
        notificationService.markAsRead(id, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Notification marked as read"));
    }

    @PutMapping("/read-all")
    public ResponseEntity<?> markAllAsRead() {
        notificationService.markAllAsRead(CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("All notifications marked as read"));
    }
}
