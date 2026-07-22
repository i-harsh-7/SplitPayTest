package com.splitpay.service;

import com.splitpay.dto.GroupDtos.CreateGroupRequest;
import com.splitpay.exception.ApiException;
import com.splitpay.model.Group;
import com.splitpay.repository.ExpenseRepository;
import com.splitpay.repository.GroupRepository;
import com.splitpay.repository.InviteRepository;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;

/**
 * Group CRUD ported from controllers/groupController.js.
 *
 * <p>Adds authorization the original Node controller lacked: only a member may read a group, only
 * the creator (admin) may delete it, and deleting a group cascades to its expenses and invites.
 */
@Service
public class GroupService {

    private final GroupRepository groupRepository;
    private final ExpenseRepository expenseRepository;
    private final InviteRepository inviteRepository;

    public GroupService(GroupRepository groupRepository, ExpenseRepository expenseRepository,
                        InviteRepository inviteRepository) {
        this.groupRepository = groupRepository;
        this.expenseRepository = expenseRepository;
        this.inviteRepository = inviteRepository;
    }

    /**
     * The membership model is "members is the single source of truth": every authorization check
     * elsewhere (BillService, InviteService, NotificationService) tests {@code members.contains},
     * not createdBy. So the creator must always be a member, or they'd be locked out of their own
     * group's expenses and invites. {@link LinkedHashSet} dedupes if the caller also passed the
     * creator's id in {@code req.members()}, while preserving the given ordering.
     */
    public Group createGroup(CreateGroupRequest req, String creatorId) {
        LinkedHashSet<String> members = new LinkedHashSet<>();
        members.add(creatorId);
        if (req.members() != null) {
            members.addAll(req.members());
        }
        Group group = Group.builder()
                .name(req.name())
                .members(new ArrayList<>(members))
                .createdBy(creatorId)
                .build();
        return groupRepository.save(group);
    }

    public Group getGroup(String id, String requesterId) {
        if (!StringUtils.hasText(id)) {
            throw ApiException.badRequest("Group ID is required");
        }
        Group group = groupRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!isMemberOrCreator(group, requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        return group;
    }

    /** Belonging to zero groups is a valid state (e.g. a brand-new user) — returns an empty list. */
    public List<Group> getAllGroups(String userId) {
        if (!StringUtils.hasText(userId)) {
            throw ApiException.badRequest("no such person exist");
        }
        return groupRepository.findByCreatedByOrMember(userId);
    }

    public void deleteGroup(String id, String requesterId) {
        if (!StringUtils.hasText(id)) {
            throw ApiException.badRequest("group doesn't exist");
        }
        Group group = groupRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        // Only the group's creator (admin) may delete it.
        if (group.getCreatedBy() == null || !group.getCreatedBy().equals(requesterId)) {
            throw ApiException.forbidden("Only the group admin can delete this group");
        }
        // Cascade: remove the group's expenses and invites so nothing is orphaned.
        expenseRepository.deleteByGroup(id);
        inviteRepository.deleteByGroup(id);
        groupRepository.deleteById(id);
    }

    private boolean isMemberOrCreator(Group group, String userId) {
        if (userId == null) {
            return false;
        }
        return userId.equals(group.getCreatedBy())
                || (group.getMembers() != null && group.getMembers().contains(userId));
    }
}
