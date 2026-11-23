/*
 * SPDX-FileCopyrightText: 2026 SUSE LLC
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
package com.redhat.rhn.taskomatic.task.repomd;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import java.util.Optional;

class SaltProtocolAbiTest {

    private static SaltProtocolAbi abi(String value) {
        return SaltProtocolAbi.parse(value).orElseThrow();
    }

    @Test
    void parsesValidValue() {
        assertEquals(new SaltProtocolAbi(3007, 1, 2), abi("3007.1.2"));
    }

    @Test
    void rejectsInvalidValues() {
        assertEquals(Optional.empty(), SaltProtocolAbi.parse(null));
        assertEquals(Optional.empty(), SaltProtocolAbi.parse(""));
        assertEquals(Optional.empty(), SaltProtocolAbi.parse("3007.1"));
        assertEquals(Optional.empty(), SaltProtocolAbi.parse("3007.x.0"));
    }

    @Test
    void equalAbiIsCompatible() {
        assertTrue(abi("3007.1.0").isCompatibleWith(abi("3007.1.0")));
    }

    @Test
    void higherMajorOrAuthIsIncompatible() {
        assertFalse(abi("3008.0.0").isCompatibleWith(abi("3007.1.0")));
        assertFalse(abi("3007.2.0").isCompatibleWith(abi("3007.1.0")));
    }

    @Test
    void lowerMajorOrAuthIgnoresTiebreaker() {
        assertTrue(abi("3006.1.9").isCompatibleWith(abi("3007.1.0")));
        assertTrue(abi("3007.0.9").isCompatibleWith(abi("3007.1.0")));
    }

    @Test
    void tiebreakerOnlyMattersWhenMajorAndAuthAreEqual() {
        assertFalse(abi("3007.1.1").isCompatibleWith(abi("3007.1.0")));
        assertTrue(abi("3007.1.0").isCompatibleWith(abi("3007.1.1")));
    }
}
