/*
 * SPDX-FileCopyrightText: 2026 SUSE LLC
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
package com.redhat.rhn.taskomatic.task.repomd;

import java.util.Optional;

/**
 * Salt protocol ABI in the form {@code <major>.<auth>.<tiebreaker>}, as provided by Salt packages
 * via the {@code salt-protocol-abi} capability.
 *
 * @param major Salt major version
 * @param auth Salt auth version
 * @param tiebreaker value bumped in special circumstances
 */
public record SaltProtocolAbi(int major, int auth, int tiebreaker) {

    /** Name of the capability provided by Salt packages. */
    public static final String CAPABILITY_NAME = "salt-protocol-abi";

    /**
     * Parse an ABI string.
     * @param value the string, e.g. "3007.1.0"
     * @return the ABI, or empty if the value is not in the expected format
     */
    public static Optional<SaltProtocolAbi> parse(String value) {
        if (value == null) {
            return Optional.empty();
        }
        String[] parts = value.trim().split("\\.");
        if (parts.length != 3) {
            return Optional.empty();
        }
        try {
            return Optional.of(new SaltProtocolAbi(
                    Integer.parseInt(parts[0]), Integer.parseInt(parts[1]), Integer.parseInt(parts[2])));
        }
        catch (NumberFormatException e) {
            return Optional.empty();
        }
    }

    /**
     * Check whether a Salt Minion package with this ABI can work with the given Salt Master.
     * This is not an RPM version comparison.
     * @param master the ABI of the Salt Master
     * @return true if this (minion) ABI is compatible with the master
     */
    public boolean isCompatibleWith(SaltProtocolAbi master) {
        if (major > master.major || auth > master.auth) {
            return false;
        }
        return major < master.major || auth < master.auth || tiebreaker <= master.tiebreaker;
    }
}
