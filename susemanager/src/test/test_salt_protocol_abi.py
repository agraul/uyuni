# SPDX-FileCopyrightText: 2026 SUSE LLC
#
# SPDX-License-Identifier: GPL-2.0-only
# pylint: disable=missing-module-docstring,missing-function-docstring

import pytest

from spacewalk.susemanager.salt_protocol_abi import SaltProtocolAbi, parse


@pytest.mark.parametrize(
    "value, expected",
    [
        ("3007.1.0", SaltProtocolAbi(3007, 1, 0)),
        (" 3006.3.2\n", SaltProtocolAbi(3006, 3, 2)),
        (None, None),
        ("", None),
        ("3007.1", None),
        ("3007.1.0.1", None),
        ("3007.x.0", None),
        ("3007.-1.0", None),
    ],
)
def test_parse(value, expected):
    assert parse(value) == expected


@pytest.mark.parametrize(
    "minion, master, compatible",
    [
        ("3006.1.0", "3006.1.0", True),
        ("3006.1.0", "3007.1.0", True),
        ("3006.0.5", "3006.1.0", True),
        ("3006.1.0", "3006.1.1", True),
        ("3006.1.1", "3006.1.0", False),
        ("3006.3.0", "3006.1.0", False),
        ("3008.1.0", "3007.1.0", False),
        # a lower major version does not allow a higher auth version
        ("3006.2.0", "3007.1.0", False),
        # the tiebreaker only matters when major and auth versions are equal
        ("3006.1.9", "3007.1.0", True),
        ("3007.0.9", "3007.1.0", True),
    ],
)
def test_is_compatible_with(minion, master, compatible):
    assert parse(minion).is_compatible_with(parse(master)) is compatible


def test_str():
    assert str(SaltProtocolAbi(3007, 1, 0)) == "3007.1.0"
