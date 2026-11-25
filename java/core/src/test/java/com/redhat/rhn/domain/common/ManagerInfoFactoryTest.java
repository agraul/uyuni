/*
 * SPDX-FileCopyrightText: 2026 SUSE LLC
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

package com.redhat.rhn.domain.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.redhat.rhn.common.hibernate.HibernateFactory;
import com.redhat.rhn.testing.BaseTestCase;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

public class ManagerInfoFactoryTest extends BaseTestCase {

    @BeforeEach
    public void deleteManagerInfo() {
        HibernateFactory.getSession().createNativeMutationQuery("DELETE FROM suseManagerInfo").executeUpdate();
    }

    @Test
    public void testSaltProtocolAbiUnknownWithoutRow() {
        assertTrue(ManagerInfoFactory.getSaltProtocolAbi().isEmpty());
    }

    @Test
    public void testSaltProtocolAbiNextToLastMgrSyncRefresh() {
        HibernateFactory.getSession()
                .createNativeMutationQuery("INSERT INTO suseManagerInfo (salt_protocol_abi) VALUES ('3007.1.0')")
                .executeUpdate();

        assertEquals(Optional.of("3007.1.0"), ManagerInfoFactory.getSaltProtocolAbi());
        assertTrue(ManagerInfoFactory.getLastMgrSyncRefresh().isEmpty());

        ManagerInfoFactory.setLastMgrSyncRefresh(1000L);

        assertEquals(1000L, ManagerInfoFactory.getLastMgrSyncRefresh().orElseThrow().getTime());
        assertEquals(Optional.of("3007.1.0"), ManagerInfoFactory.getSaltProtocolAbi());
        Long rows = HibernateFactory.getSession()
                .createNativeQuery("SELECT COUNT(*) FROM suseManagerInfo", Long.class)
                .getSingleResult();
        assertEquals(1L, rows);
    }
}
