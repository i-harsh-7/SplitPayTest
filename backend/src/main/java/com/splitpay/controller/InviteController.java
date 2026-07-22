package com.splitpay.controller;

import com.splitpay.dto.InviteDtos.InviteActionRequest;
import com.splitpay.dto.InviteDtos.SendInviteRequest;
import com.splitpay.model.Group;
import com.splitpay.model.Invite;
import com.splitpay.repository.GroupRepository;
import com.splitpay.security.CurrentUser;
import com.splitpay.service.InviteService;
import com.splitpay.service.ResponseMapper;
import com.splitpay.web.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Group-invite endpoints under /api/v1/group/invite, matching inviteRoutes.js.
 */
@RestController
@RequestMapping("/api/v1/group/invite")
public class InviteController {

    private final InviteService inviteService;
    private final GroupRepository groupRepository;
    private final ResponseMapper responseMapper;

    public InviteController(InviteService inviteService, GroupRepository groupRepository,
                            ResponseMapper responseMapper) {
        this.inviteService = inviteService;
        this.groupRepository = groupRepository;
        this.responseMapper = responseMapper;
    }

    @PostMapping
    public ResponseEntity<?> sendInvite(@Valid @RequestBody SendInviteRequest req) {
        Invite invite = inviteService.sendInvite(req.groupId(), req.friendMail(), CurrentUser.id());
        Group group = groupRepository.findById(invite.getGroup()).orElse(null);
        return ResponseEntity.ok(ApiResponse.success("the invite link sent successfully")
                .with("inviteLink", responseMapper.populateInvite(invite, group)));
    }

    @PostMapping("/accept")
    public ResponseEntity<?> acceptInvite(@Valid @RequestBody InviteActionRequest req) {
        Group group = inviteService.acceptInvite(req.inviteId(), CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("the invite is accepted and added to the group")
                .with("group", responseMapper.populateGroup(group)));
    }

    @PostMapping("/reject")
    public ResponseEntity<?> rejectInvite(@Valid @RequestBody InviteActionRequest req) {
        inviteService.rejectInvite(req.inviteId(), CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("rejected the link to join the group"));
    }

    @GetMapping("/pending")
    public ResponseEntity<?> getPending() {
        List<Invite> invites = inviteService.getPendingInvites(CurrentUser.id());
        List<Object> populated = invites.stream()
                .map(inv -> (Object) responseMapper.populateInvite(
                        inv, groupRepository.findById(inv.getGroup()).orElse(null)))
                .toList();
        return ResponseEntity.ok(ApiResponse.ok()
                .with("count", invites.size())
                .with("invites", populated));
    }
}
