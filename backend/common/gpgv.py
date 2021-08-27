"""Verify GPG signatures with gpgv."""

import subprocess
import sys
import logging

HANDLERS = {}


def gpgv(*, signed_file, keyring) -> bool:
    return _run_gpgv(signed_file=signed_file, keyring=keyring)


def gpgv_detached(*, signature_file, signed_file, keyring) -> bool:
    return _run_gpgv(
        signed_file=signed_file, signature_file=signature_file, keyring=keyring
    )


def _run_gpgv(signed_file, signature_file=None, keyring=None) -> bool:
    cmd = [
        "gpgv",
        "--status-fd",
        sys.stdout,
    ]
    if keyring is not None:
        cmd.extend(["--keyring", keyring])
    cmd.append(signed_file)
    if signature_file is not None:
        cmd.append(signature_file)

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, timeout=90)

    # All signatures are valid
    if proc.returncode == 0:
        return True
    else:
        return _parse_gpgv(str(proc.stdout))


def _parse_gpgv(process_output: str) -> bool:
    PREFIX = "[GNUPG:]"
    for line in process_output.split("\n"):
        if not line.startswith(PREFIX):
            continue

        content = line[len(PREFIX) :]
        keyword, *args = content.split()

        handler = HANDLERS.get(keyword.lower())
        if handler is None:
            continue

        return handler(*args)

    return False


def _handle_newsig(signers_uid=None):
    ...


def _handle_goodsig(keyid, username):
    ...


def _handle_expsig(keyid, username):
    ...


def _handle_expkeysig(keyid, username):
    ...


def _handle_revkeysig(keyid, username):
    ...


def _handle_badsig(keyid, username):
    ...


def _handle_errsig(keyid, pkalgo, hashalgo, sig_class, time, rc, fpr):
    ...


def _handle_validsig(
    fingerprint,
    sig_creation_time,
    sig_timestamp,
    expiry_timestamp,
    sig_version,
    reserved,
    pubkey_algo,
    hash_algo,
    sig_class,
    primary_key_fingerprint=None,
):
    ...
