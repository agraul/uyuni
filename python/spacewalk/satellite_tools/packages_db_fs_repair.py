#!/usr/bin/python3
"""Script to sync database (rhnPackage table) with the file system.

Problem 1: Database package["path"] is wrong
Solution: Find package in file system and update path in database

Problem 2: Package is missing in file system
Solution: Delete package from database

--- Not yet implemented ---
Problem 3: Package is missing from the database
Solution: Delete package from file system (or insert as orphan?)

Problem n: ...
Solution: ...
"""

import argparse
import logging
import pathlib
import sys
from typing import Sequence

from spacewalk.common.rhnConfig import cfg_component
from spacewalk.server import rhnPackage, rhnSQL

logger = logging.getLogger(__name__)
logger.addHandler(logging.StreamHandler(sys.stderr))

def query_db_packages(use_checksum=False, use_nevrao=False):
    """Query DB for all packages and return an iterator."""
    columns = "p.id, p.org_id, p.package_size, p.path"
    tables = "rhnPackage p"
    if use_checksum or use_nevrao:
        columns += ", c.checksum, c.checksum_type"
        tables += " join rhnChecksumView c on p.checksum_id = c.id"
    if use_nevrao:
        columns += ", n.name, evr.epoch, evr.version, evr.release, a.label as arch"
        tables += " join rhnPackageName n on p.name_id = n.id"
        tables += " join rhnPackageEVR evr on p.evr_id = evr.id"
        tables += " join rhnPackageArch a on p.package_arch_id = a.id"

    query = f"SELECT {columns} FROM {tables}"
    db = rhnSQL.prepare(query)
    logger.debug("SQL: executing query: %s", query)
    row_count = db.execute()
    if row_count:
        # FIXME: Is not a dict, nor a namedtuple
        yield from db._real_cursor
    else:
        return []


def compare_db_to_file_system(db_rows: Sequence, root: str):
    """compare db_rows to the file system starting at root.

    Mismatches are returned together with the required fix"""
    ret = []
    for row in db_rows:
        (
            pid,
            org_id,
            psize,
            path,
            checksum,
            checksum_type,
            name,
            epoch,
            version,
            release,
            arch,
        ) = row
        logger.debug("Checking path for package id '%s'", pid)
        if not path or (isinstance(path, str) and path.strip() == ""):
            logger.debug("Path is NULL/empty!")
            fs_path = find_file(name, epoch, version, release, arch, checksum, org_id)
            if fs_path:
                ret.append(
                    {
                        "message": f"File '{fs_path.name}' exists but is not in the db.",
                        "fix": {
                            "db": (
                                "UPDATE rhnPackage SET path = :path WHERE id = :id",
                                {"id": pid, "path": str(fs_path)},
                            )
                        },
                    }
                )
            else:
                ret.append(
                    {
                        "message": "Package has no 'path' and can't be found in the file system.",
                        # Destructive, let's leave it out for now
                        # "fix": {
                        #     "db": ("DELETE from rhnPackage WHERE id = :id", {"id": pid})
                        # },
                    }
                )
    return ret


def find_file(name, epoch, version, release, arch, checksum, org):
    """Returns pathlib.Path instance if the file exists or None."""
    if org is None:
        org = "NULL"
    # build file path based on package metadata
    with cfg_component("server") as cfg:
        root = cfg.mount_point
    checksum_prefix = checksum[:3]
    evr = _evr(epoch=epoch, version=version, release=release)
    basename = f"{name}-{version}-{release}.{arch}.rpm"
    path = (
        pathlib.Path(root)
        / "packages"
        / org
        / checksum_prefix
        / name
        / evr
        / arch
        / checksum
        / basename
    )
    logger.debug("Checking '%s' for '%s'", path, basename)
    exists = path.exists()
    if exists:
        logger.debug("File '%s' exists.", path)
        return path
    else:
        logger.debug("File '%s' does not exist.", path)
        return None


def _evr(epoch="", version="", release=""):
    if epoch:
        evr = f"{epoch}:{version}-{release}"
    else:
        evr = f"{version}-{release}"
    return evr


def fix(instructions):
    """Apply fixes specified in instructions dict."""
    if "db" in instructions:
        query, args = instructions["db"]
        logger.debug("Running query: '%s' with args '%s'", query, args)
        rhnSQL.execute(query, **args)
        rhnSQL.commit()
    elif "fs" in instructions:
        ...


if __name__ == "__main__":
    run_fix = False
    logger.setLevel(logging.INFO)
    if "-v" in sys.argv:
        logger.setLevel(logging.DEBUG)
    if "--fix" in sys.argv:
        run_fix = True

    with cfg_component("server"):
        rhnSQL.initDB()

    pkgs_iter = query_db_packages(True, True)
    results = compare_db_to_file_system(pkgs_iter, "/var/spacewalk")
    for result in results:
        if "message" in result:
            logger.info(result["message"])
        if run_fix and "fix" in result:
            fix(result["fix"])
