package com.splitpay.repository;

import com.splitpay.model.Invite;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface InviteRepository extends MongoRepository<Invite, String> {

    List<Invite> findByReceiverAndStatus(String receiver, String status);

    /** Removes all invites belonging to a group (used when the group is deleted). */
    void deleteByGroup(String group);
}
