#  pylint: disable=missing-module-docstring
#
# SPDX-FileCopyrightText: 2026 SUSE LLC
#
# SPDX-License-Identifier: GPL-2.0-only

import importlib.machinery
import importlib.util
import os
import subprocess
from unittest.mock import MagicMock, patch

import pytest

SCRIPT = os.path.join(
    os.path.dirname(__file__),
    "../../../../../spacewalk/admin/uyuni-salt-protocol-abi",
)


def load_script():
    loader = importlib.machinery.SourceFileLoader("uyuni_salt_protocol_abi", SCRIPT)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def salt_run_result(stdout):
    return subprocess.CompletedProcess(args=[], returncode=0, stdout=stdout)


def test_get_master_abi():
    module = load_script()
    with patch.object(
        module.subprocess, "run", return_value=salt_run_result('"3007.1.0"\n')
    ) as run:
        assert module.get_master_abi() == "3007.1.0"
    assert run.call_args.args[0][-3:] == [
        "salt.cmd",
        "grains.get",
        "__suse_reserved_protocol_abi",
    ]


@pytest.mark.parametrize("stdout", ['""', '"3007.1"', '"a.b.c"', "{}", "not json"])
def test_get_master_abi_invalid_value(stdout):
    module = load_script()
    with patch.object(module.subprocess, "run", return_value=salt_run_result(stdout)):
        assert module.get_master_abi() is None


@pytest.mark.parametrize(
    "error",
    [
        FileNotFoundError("salt-run"),
        subprocess.CalledProcessError(1, "salt-run"),
        subprocess.TimeoutExpired("salt-run", 300),
    ],
)
def test_get_master_abi_salt_run_fails(error):
    module = load_script()
    with patch.object(module.subprocess, "run", side_effect=error):
        assert module.get_master_abi() is None


def run_store_abi(module, stored_row):
    select = MagicMock()
    select.fetchone_dict.return_value = stored_row
    write = MagicMock()
    with patch.object(module.rhnSQL, "initDB"), patch.object(
        module.rhnSQL, "prepare", side_effect=[select, write]
    ) as prepare, patch.object(module.rhnSQL, "commit") as commit:
        changed = module.store_abi("3007.1.0")
    return changed, prepare, write, commit


def test_store_abi_updates_existing_row():
    module = load_script()
    changed, prepare, write, commit = run_store_abi(
        module, {"salt_protocol_abi": "3006.0.0"}
    )

    assert changed
    assert prepare.call_args.args[0].startswith("UPDATE suseManagerInfo")
    write.execute.assert_called_once_with(abi="3007.1.0")
    commit.assert_called_once()


def test_store_abi_inserts_missing_row():
    module = load_script()
    changed, prepare, write, commit = run_store_abi(module, None)

    assert changed
    assert prepare.call_args.args[0].startswith("INSERT INTO suseManagerInfo")
    write.execute.assert_called_once_with(abi="3007.1.0")
    commit.assert_called_once()


def test_store_abi_unchanged():
    module = load_script()
    changed, _, write, commit = run_store_abi(module, {"salt_protocol_abi": "3007.1.0"})

    assert not changed
    write.execute.assert_not_called()
    commit.assert_not_called()


def test_main_stores_abi():
    module = load_script()
    with patch.object(module, "get_master_abi", return_value="3007.1.0"), patch.object(
        module, "store_abi"
    ) as store_abi:
        assert module.main() == 0

    store_abi.assert_called_once_with("3007.1.0")


def test_main_keeps_previous_value_when_unknown():
    module = load_script()
    with patch.object(module, "get_master_abi", return_value=None), patch.object(
        module, "store_abi"
    ) as store_abi:
        assert module.main() == 0

    store_abi.assert_not_called()
