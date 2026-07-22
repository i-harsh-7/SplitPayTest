package com.splitpay.service;

import com.splitpay.exception.ApiException;
import com.splitpay.model.Group;
import com.splitpay.model.Invite;
import com.splitpay.model.User;
import com.splitpay.repository.GroupRepository;
import com.splitpay.repository.InviteRepository;
import com.splitpay.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Invite flow ported from controllers/inviteController.js: send, accept, reject and list pending.
 */
@Service
public class InviteService {

    private final InviteRepository inviteRepository;
    private final GroupRepository groupRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    public InviteService(InviteRepository inviteRepository, GroupRepository groupRepository,
                         UserRepository userRepository, NotificationService notificationService) {
        this.inviteRepository = inviteRepository;
        this.groupRepository = groupRepository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    public Invite sendInvite(String groupId, String friendMail, String senderId) {
        Group group = groupRepository.findById(groupId)
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(senderId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        User receiver = userRepository.findByEmail(friendMail)
                .orElseThrow(() -> ApiException.notFound("User not found"));
        if (group.getMembers().contains(receiver.getId())) {
            throw ApiException.badRequest("User already in group");
        }
        return inviteRepository.save(Invite.builder()
                .group(groupId)
                .sender(senderId)
                .receiver(receiver.getId())
                .status("pending")
                .build());
    }

    /** Accepts the invite and adds the receiver to the group. Returns the updated group. */
    public Group acceptInvite(String inviteId, String userId) {
        Invite invite = inviteRepository.findById(inviteId)
                .orElseThrow(() -> ApiException.notFound("the invite doesn't exits"));
        if (!invite.getReceiver().equals(userId)) {
            throw ApiException.forbidden("not authorized");
        }
        Group group = groupRepository.findById(invite.getGroup())
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(userId)) {
            group.getMembers().add(userId);
            groupRepository.save(group);
        }
        invite.setStatus("accepted");
        inviteRepository.save(invite);

        // Notify the original sender that their invite was accepted.
        String actorName = userRepository.findById(userId).map(User::getName).orElse("A user");
        notificationService.create(
                invite.getSender(),
                "invite_accepted",
                "Invite Accepted",
                actorName + " has accepted your invitation to join " + group.getName(),
                userId,
                group.getId());
        return group;
    }

    public void rejectInvite(String inviteId, String userId) {
        Invite invite = inviteRepository.findById(inviteId)
                .orElseThrow(() -> ApiException.notFound("invite doesn't exists"));
        if (!invite.getReceiver().equals(userId)) {
            throw ApiException.forbidden("not authorized");
        }
        invite.setStatus("rejected");
        inviteRepository.save(invite);

        // Notify the original sender that their invite was declined.
        String actorName = userRepository.findById(userId).map(User::getName).orElse("A user");
        String groupName = groupRepository.findById(invite.getGroup())
                .map(Group::getName).orElse("the group");
        notificationService.create(
                invite.getSender(),
                "invite_rejected",
                "Invite Declined",
                actorName + " has declined your invitation to join " + groupName,
                userId,
                invite.getGroup());
    }

    public List<Invite> getPendingInvites(String userId) {
        return inviteRepository.findByReceiverAndStatus(userId, "pending");
    }
}
