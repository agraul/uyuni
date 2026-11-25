# SPDX-FileCopyrightText: 2026 SUSE LLC
#
# SPDX-License-Identifier: GPL-2.0-only

"""
Salt protocol ABI in the form "<major>.<auth>.<tiebreaker>", as provided by Salt packages
via the "salt-protocol-abi" capability and reported by the Salt Master.
"""

from typing import NamedTuple, Optional

CAPABILITY_NAME = "salt-protocol-abi"


class SaltProtocolAbi(NamedTuple):
    """Salt protocol ABI of a Salt package or the Salt Master."""

    major: int
    auth: int
    tiebreaker: int

    def __str__(self):
        return f"{self.major}.{self.auth}.{self.tiebreaker}"

    def is_compatible_with(self, master: "SaltProtocolAbi") -> bool:
        """
        Check whether a Salt Minion package with this ABI can work with the given Salt Master.
        This is not an RPM version comparison.
        """
        if self.major > master.major or self.auth > master.auth:
            return False
        if (self.major, self.auth) == (master.major, master.auth):
            return self.tiebreaker <= master.tiebreaker
        return True


def parse(value: Optional[str]) -> Optional[SaltProtocolAbi]:
    """
    Parse an ABI string like "3007.1.0". Return None if the value is not in the expected format.
    """
    parts = (value or "").strip().split(".")
    if len(parts) != 3 or not all(part.isdecimal() for part in parts):
        return None
    return SaltProtocolAbi(*(int(part) for part in parts))
