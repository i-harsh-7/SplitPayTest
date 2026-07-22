package com.splitpay.service;

import com.splitpay.model.Expense;
import com.splitpay.model.Group;
import com.splitpay.model.Invite;
import com.splitpay.model.Notification;
import com.splitpay.model.User;
import com.splitpay.repository.GroupRepository;
import com.splitpay.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Reproduces Mongoose's {@code .populate(...)} behaviour by hand-building response maps.
 *
 * <p>This layer exists for one reason: contract fidelity. The Flutter client reads MongoDB-style
 * {@code _id} keys and expects reference fields (createdBy, members, assignment from/to, payment
 * user) to be expanded into {name,email,_id} subdocuments — exactly what the Node controllers
 * produced via {@code .populate("members","name email")}. Spring would otherwise serialize the id
 * field as "id" and leave references as bare strings, so we assemble the maps explicitly.
 */
@Service
public class ResponseMapper {

    private final UserRepository userRepository;
    private final GroupRepository groupRepository;

    public ResponseMapper(UserRepository userRepository, GroupRepository groupRepository) {
        this.userRepository = userRepository;
        this.groupRepository = groupRepository;
    }

    // ----- users ---------------------------------------------------------------------------

    /** {@code .populate(ref, "name email")} → { _id, name, email }, or null when the id is null. */
    public Map<String, Object> populateUserBrief(String userId) {
        if (userId == null) {
            return null;
        }
        return userRepository.findById(userId)
                .map(u -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("_id", u.getId());
                    m.put("name", u.getName());
                    m.put("email", u.getEmail());
                    return m;
                })
                // If the referenced user no longer exists, return the bare id like Mongoose would
                // leave an unpopulated ObjectId.
                .orElseGet(() -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("_id", userId);
                    return m;
                });
    }

    /** Full user object for auth responses: { _id, name, email, youOwe, youAreOwed } (no password). */
    public Map<String, Object> userPublic(User user) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", user.getId());
        m.put("name", user.getName());
        m.put("email", user.getEmail());
        m.put("phone", user.getPhone());
        m.put("youOwe", user.getYouOwe());
        m.put("youAreOwed", user.getYouAreOwed());
        m.put("createdAt", user.getCreatedAt());
        m.put("updatedAt", user.getUpdatedAt());
        return m;
    }

    // ----- groups --------------------------------------------------------------------------

    /** A group with members + createdBy populated, matching getGroup/createGroup responses. */
    public Map<String, Object> populateGroup(Group group) {
        if (group == null) {
            return null;
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", group.getId());
        m.put("name", group.getName());
        m.put("members", group.getMembers().stream()
                .map(this::populateUserBrief)
                .collect(Collectors.toList()));
        m.put("createdBy", populateUserBrief(group.getCreatedBy()));
        m.put("createdAt", group.getCreatedAt());
        m.put("updatedAt", group.getUpdatedAt());
        return m;
    }

    public List<Map<String, Object>> populateGroups(List<Group> groups) {
        return groups.stream().map(this::populateGroup).collect(Collectors.toList());
    }

    // ----- expenses ------------------------------------------------------------------------

    /**
     * Full expense with createdBy, assignments.from/to and payments.user populated — covers
     * uploadBill, getBillDetails, assignMoney, assignEqually, settleAssignments, getAllBills.
     */
    public Map<String, Object> populateExpense(Expense e) {
        if (e == null) {
            return null;
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", e.getId());
        m.put("billName", e.getBillName());
        m.put("group", e.getGroup()); // kept as id string, as the client only reads expense-level fields
        m.put("createdBy", populateUserBrief(e.getCreatedBy()));
        m.put("billImageUrl", e.getBillImageUrl());
        m.put("items", e.getItems().stream().map(this::itemMap).collect(Collectors.toList()));
        m.put("splitMethod", e.getSplitMethod());
        m.put("totalAmount", e.getTotalAmount());
        m.put("payments", e.getPayments().stream().map(this::paymentMap).collect(Collectors.toList()));
        m.put("assignments", e.getAssignments().stream().map(this::assignmentMap).collect(Collectors.toList()));
        m.put("splitSummary", e.getSplitSummary());
        m.put("createdAt", e.getCreatedAt());
        m.put("updatedAt", e.getUpdatedAt());
        return m;
    }

    public List<Map<String, Object>> populateExpenses(List<Expense> expenses) {
        return expenses.stream().map(this::populateExpense).collect(Collectors.toList());
    }

    private Map<String, Object> itemMap(Expense.Item item) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("name", item.getName());
        m.put("price", item.getPrice());
        m.put("quantity", item.getQuantity());
        // assignedTo is a list of user-id references; populate each to {_id,name,email}.
        m.put("assignedTo", item.getAssignedTo().stream()
                .map(this::populateUserBrief)
                .collect(Collectors.toList()));
        return m;
    }

    private Map<String, Object> assignmentMap(Expense.Assignment a) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", a.getId());
        m.put("from", populateUserBrief(a.getFrom()));
        m.put("to", populateUserBrief(a.getTo()));
        m.put("amount", a.getAmount());
        m.put("isPaid", a.isPaid());
        m.put("paidAt", a.getPaidAt());
        return m;
    }

    private Map<String, Object> paymentMap(Expense.Payment p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", p.getId());
        m.put("user", populateUserBrief(p.getUser()));
        m.put("amount", p.getAmount());
        m.put("method", p.getMethod());
        m.put("createdAt", p.getCreatedAt());
        return m;
    }

    // ----- invites -------------------------------------------------------------------------

    /** Pending invite with group + sender populated, matching getPendingInvite. */
    public Map<String, Object> populateInvite(Invite invite, Group group) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", invite.getId());
        // The client reads group._id and group.groupName/name; include both for safety.
        if (group != null) {
            Map<String, Object> g = new LinkedHashMap<>();
            g.put("_id", group.getId());
            g.put("name", group.getName());
            g.put("groupName", group.getName());
            m.put("group", g);
        } else {
            m.put("group", invite.getGroup());
        }
        m.put("sender", populateUserBrief(invite.getSender()));
        m.put("receiver", populateUserBrief(invite.getReceiver()));
        m.put("status", invite.getStatus());
        m.put("createdAt", invite.getCreatedAt());
        m.put("updatedAt", invite.getUpdatedAt());
        return m;
    }

    // ----- notifications -------------------------------------------------------------------

    /**
     * A notification shaped for the Flutter client, which reads {@code type}, {@code title},
     * {@code message}, {@code createdAt}, {@code read}, and nested {@code user}/{@code group}
     * objects (with {@code name}) when present.
     */
    public Map<String, Object> populateNotification(Notification n) {
        if (n == null) {
            return null;
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("_id", n.getId());
        m.put("type", n.getType());
        m.put("title", n.getTitle());
        m.put("message", n.getMessage());
        if (n.getRelatedUser() != null) {
            m.put("user", populateUserBrief(n.getRelatedUser()));
        }
        if (n.getRelatedGroup() != null) {
            Map<String, Object> g = new LinkedHashMap<>();
            g.put("_id", n.getRelatedGroup());
            groupRepository.findById(n.getRelatedGroup())
                    .ifPresent(grp -> g.put("name", grp.getName()));
            m.put("group", g);
        }
        m.put("read", n.isRead());
        m.put("createdAt", n.getCreatedAt());
        return m;
    }

    public List<Map<String, Object>> populateNotifications(List<Notification> notifications) {
        return notifications.stream().map(this::populateNotification).collect(Collectors.toList());
    }
}
