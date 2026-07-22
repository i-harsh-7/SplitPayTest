package com.splitpay.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public final class InviteDtos {

    private InviteDtos() {
    }

    /** Body for POST /group/invite. The original read { groupId, friendMail }. */
    public record SendInviteRequest(
            @NotBlank(message = "groupId is required") String groupId,
            @NotBlank(message = "friendMail is required") @Email(message = "friendMail must be a valid email address") String friendMail) {
    }

    /** Body for accept/reject. The original read { inviteId }. */
    public record InviteActionRequest(@NotBlank(message = "inviteId is required") String inviteId) {
    }
}
