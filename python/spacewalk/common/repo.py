"""
Repository tools
"""

import hashlib
import http
import logging
import lzma
import os
import subprocess
import tempfile
import zlib
from collections import namedtuple
from typing import Any, Dict, Generator, List, Optional, Tuple
from urllib import parse

import requests
from spacewalk.common import fileutils
from spacewalk.common.rhnConfig import cfg_component

SPACEWALK_LIB = "/var/lib/spacewalk"
SPACEWALK_GPG_HOMEDIR = os.path.join(SPACEWALK_LIB, "gpgdir")

# Length of hexadecimal representation for each checksum algorithm
LEN_MD5 = 128 // 4
LEN_SHA1 = 160 // 4
LEN_SHA256 = 256 // 4
LEN_SHA384 = 384 // 4
LEN_SHA512 = 512 // 4

logger = logging.getLogger(__name__)


class EpochVersionRelease:
    def __init__(
        self,
        epoch: Optional[str] = None,
        version: Optional[str] = None,
        release: Optional[str] = None,
        *,
        evr_str: Optional[str] = None,
    ):
        if all(x is not None for x in (epoch, version, release)):
            self.epoch = epoch
            self.version = version
            self.release = release
        elif evr_str is not None:
            self.epoch, self.version, self.release = self._parse_evr_str(evr_str)
        else:
            raise ValueError(
                "Either all of epoch, version, release, or an evr_str must to be provided."
            )

    def _parse_evr_str(self, evr_str):
        if not evr_str:
            return "", "", ""

        epoch, _, version_release = evr_str.rpartition(":")
        version, _, release = version_release.partition("-")
        # HACK: this is for backwards-compatibility introduced by
        # https://github.com/uyuni-project/uyuni/commit/fb7be313d1737316390b5a445c9c225680caa757
        # ContentPackage.setNVREA() currently does not allow unset release
        if not release:
            release = "X"
        return epoch, version, release

    def astuple(self):
        return (self.epoch, self.version, self.release)

    def __eq__(self, other):
        return self.astuple() == other.astuple()

    def __str__(self):
        # assums self.version is always set, self.epoch & self.release are optional
        epoch_str = release_str = ""
        if self.epoch:
            epoch_str = f"{self.epoch}:"
        if self.release:
            release_str = f"-{self.release}"

        return f"{epoch_str}{self.version}{release_str}"


class GeneralRepoException(Exception):
    """
    Dpkg repository exception
    """


class DebPackage:
    """Representation of a single deb package."""

    def __init__(self):
        self.name: Optional[str] = None
        self.epoch: Optional[str] = None
        self.version: Optional[str] = None
        self.release: Optional[str] = None
        self.arch: Optional[str] = None
        self.relativepath: Optional[str] = None
        self.checksum_type: Optional[str] = None
        self.checksum: Optional[str] = None
        self.description: Optional[str] = None

    # dict-like access
    def __getitem__(self, key):
        return getattr(self, key)

    def __setitem__(self, key, value):
        return setattr(self, key, value)

    def __repr__(self):
        return f"DebPackage(name={self.name}, evr={self.evr()}, arch={self.arch}"

    def evr(self):
        "Return the epoch:version-release string."
        # evr might have changed since the last time this was called
        evr = EpochVersionRelease(self.epoch, self.version, self.release)
        return str(evr)

    def is_populated(self) -> bool:
        """Return whether all fields were set.

        The only exception is "description", which is not always avaliable.
        """
        return all(
            [
                attribute is not None
                for attribute in (
                    self.name,
                    self.epoch,
                    self.version,
                    self.release,
                    self.arch,
                    self.relativepath,
                    self.checksum_type,
                    self.checksum,
                )
            ]
        )


class DpkgRepo:
    """
    Dpkg repository detection.
    The repositories in Debian world have several layouts,
    such as "flat", classic tree, PPA etc.
    """

    PKG_GZ = "Packages.gz"
    PKG_XZ = "Packages.xz"
    PKG_RW = "Packages"

    class ReleaseEntry:
        """
        Release file entry
        """

        class Checksum:
            """
            Checksums of the Release file
            """

            md5: str = ""
            sha1: str = ""
            sha256: str = ""
            sha384: str = ""
            sha512: str = ""

        def __init__(self, size: int, uri: str):
            self.checksum = DpkgRepo.ReleaseEntry.Checksum()
            self.size = size
            self.uri = uri

    class EntryDict(dict):
        """
        Parsed release container.
        """

        def __init__(self, repo: "DpkgRepo"):
            super().__init__()
            self.__repo = repo

        def get(self, key: Any) -> Optional[Any]:
            """
            Automatically update key if the repo is flat.

            :param key:
            :return:
            """
            if not self.__repo.is_flat():
                key = "/".join(
                    parse.urlparse(self.__repo.url).path.strip("/").split("/")[-2:]
                    + [key]
                )
            return self[key]

    def __init__(
        self,
        url: str,
        cachedir: str,
        proxies: Optional[dict] = None,
        gpg_verify: bool = True,
        timeout: Optional[int] = None,
    ):
        self.url = url
        self._flat_checked: Optional[int] = None
        self._flat: bool = False
        self._pkg_index: Tuple[str, bytes] = (
            "",
            b"",
        )
        self.cachedir = cachedir
        self.description_cachedir = os.path.join(self.cachedir, "descriptions/")
        self._release = DpkgRepo.EntryDict(self)
        self.proxies = proxies
        self.gpg_verify = gpg_verify
        self.timeout = timeout

    @staticmethod
    def _get_parent_url(url, depth=1, add_path=""):
        """
        Get parent url from the given one.

        :param url: an url
        :return: parent url
        """
        p_url = parse.urlparse(url)
        p_path = p_url.path.rstrip("/").split("/")
        if depth:
            p_path = p_path[:-depth]

        return parse.urlunparse(
            parse.ParseResult(
                scheme=p_url.scheme,
                netloc=p_url.netloc,
                path="/".join(p_path + add_path.strip("/").split("/")) or "/",
                params=p_url.params,
                query=p_url.query,
                fragment=p_url.fragment,
            )
        )

    def append_index_file(self, index_file: str) -> str:
        """
        Append an index file, such as Packages.gz or Packagex.xz etc
        to the given URL, if it does not contains any.

        :param index_file: string
        :return: url string
        """
        p_url = parse.urlparse(self.url)
        path = p_url.path
        if not path.endswith(index_file):
            if index_file in path:
                logging.error(
                    "URL has already %s mentioned in it. Raising GeneralRepoException!",
                    index_file,
                    exc_info=True,
                )
                raise GeneralRepoException(
                    f"URL has already {index_file} mentioned in it."
                )
            path = os.path.join(path.rstrip("/"), index_file)

        return parse.urlunparse(
            (
                p_url.scheme,
                p_url.netloc,
                path,
                p_url.params,
                p_url.query,
                p_url.fragment,
            )
        )

    def is_flat(self) -> bool:
        """
        Detect if the repository has flat format.

        :return:
        """
        if self._flat_checked is None:
            self.get_release_index()

        return bool(self._flat)

    # "Release" file parsing and verification

    def _parse_release_index(self, release: str) -> "EntryDict":
        """
        Parse release index to a structure.

        :param release: decoded content of the Release file
        :return: dictionary
        """
        Entry = namedtuple("Entry", "checksum, size, path")
        for line in release.split(os.linesep):
            try:
                entry = Entry._make(
                    filter(None, line.strip().replace("\t", " ").split(" "))
                )
                int(entry.checksum, 0x10)  # assert entry.checksum is hexadecimal
                rel_entry = DpkgRepo.ReleaseEntry(int(entry.size), entry.path)
            except (TypeError, ValueError):
                continue

            if len(entry.checksum) in (
                LEN_MD5,
                LEN_SHA1,
                LEN_SHA256,
                LEN_SHA384,
                LEN_SHA512,
            ):
                self._release.setdefault(rel_entry.uri, rel_entry)
                if len(entry.checksum) == LEN_MD5:
                    self._release[rel_entry.uri].checksum.md5 = entry.checksum
                elif len(entry.checksum) == LEN_SHA1:
                    self._release[rel_entry.uri].checksum.sha1 = entry.checksum
                elif len(entry.checksum) == LEN_SHA256:
                    self._release[rel_entry.uri].checksum.sha256 = entry.checksum
                elif len(entry.checksum) == LEN_SHA384:
                    self._release[rel_entry.uri].checksum.sha384 = entry.checksum
                elif len(entry.checksum) == LEN_SHA512:
                    self._release[rel_entry.uri].checksum.sha512 = entry.checksum

        return self._release

    def _has_valid_gpg_signature(self, uri: str, response=None) -> bool:
        """
        Validate GPG signature of Release file.

        :return: bool
        """
        process = None
        uri = uri.replace("file://", "")
        if not response:
            # There is no response, so this is a local path.
            if os.access(os.path.join(uri, "InRelease"), os.R_OK):
                release_file = os.path.join(uri, "InRelease")
                process = subprocess.Popen(
                    [
                        "gpg",
                        "--verify",
                        "--homedir",
                        SPACEWALK_GPG_HOMEDIR,
                        release_file,
                    ],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                process.wait(timeout=90)
            elif os.access(os.path.join(uri, "Release"), os.R_OK):
                release_file = os.path.join(uri, "Release")
                release_signature_file = os.path.join(uri, "Release.gpg")
                if os.access(release_signature_file, os.R_OK):
                    process = subprocess.Popen(
                        [
                            "gpg",
                            "--verify",
                            "--homedir",
                            SPACEWALK_GPG_HOMEDIR,
                            release_signature_file,
                            release_file,
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    process.wait(timeout=90)
                else:
                    logging.error(
                        "Signature file for GPG check could not be accessed: \
                                   %s. Raising GeneralRepoException.",
                        release_signature_file,
                    )
                    raise GeneralRepoException(
                        f"Signature file for GPG check could not be accessed: {release_signature_file}"
                    )
            else:
                logging.error(
                    "No release file found: '%s'. Raising GeneralRepoException.",
                    uri,
                )
                raise GeneralRepoException(f"No release file found: {uri}")
        else:
            # There is a response, so we are dealing with a URL.
            if parse.urlparse(response.url).path.endswith("InRelease"):
                process = subprocess.Popen(
                    ["gpg", "--verify", "--homedir", SPACEWALK_GPG_HOMEDIR],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                process.communicate(response.content, timeout=90)
            else:
                signature_response = requests.get(
                    self._get_parent_url(response.url, 1, "Release.gpg"),
                    proxies=self.proxies,
                    timeout=self.timeout,
                )
                if signature_response.status_code != http.HTTPStatus.OK:
                    return False
                else:
                    temp_release_file = tempfile.NamedTemporaryFile()
                    temp_release_file.write(response.content)
                    temp_release_file.seek(0)
                    temp_signature_file = tempfile.NamedTemporaryFile()
                    temp_signature_file.write(signature_response.content)
                    temp_signature_file.seek(0)
                    process = subprocess.Popen(
                        [
                            "gpg",
                            "--verify",
                            "--homedir",
                            SPACEWALK_GPG_HOMEDIR,
                            temp_signature_file.name,
                            temp_release_file.name,
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    process.wait(timeout=90)
        if process.returncode == 0:
            logging.debug("GPG signature is valid")
            return True
        else:
            logging.debug(
                "GPG signature is invalid. gpg return code: %s", process.returncode
            )
            return False

    def get_release_index(self) -> Dict[str, "DpkgRepo.ReleaseEntry"]:
        """
        Find and return contents of Release file.

        InRelease file take precedence over Release file if both exist.
        In either case the file must be signed with a GPG key. The signature is
        verified before the content is parsed.

        :raises GeneralRepoException if the Release file cannot be found or the GPG signature can't be verified.
        :return: string
        """
        if self.url.startswith("file://"):
            return self._get_release_index_from_file()
        else:
            return self._get_release_index_from_http()

    def _get_release_index_from_file(self) -> Dict[str, "DpkgRepo.ReleaseEntry"]:
        # InRelease files take precedence per uyuni-rfc 00057-deb-repo-sync-gpg-check
        logging.debug(
            "Fetching release file from local filesystem: %s",
            self.url.replace("file://", ""),
        )
        local_path = self.url.replace("file://", "")
        release_file = None
        if os.access(self._get_parent_url(local_path, 2, "InRelease"), os.R_OK):
            release_file = self._get_parent_url(local_path, 2, "InRelease")
            local_path = self._get_parent_url(local_path, 2)
            self._flat = False
        elif os.access(self._get_parent_url(local_path, 2, "Release"), os.R_OK):
            release_file = self._get_parent_url(local_path, 2, "Release")
            local_path = self._get_parent_url(local_path, 2)
            self._flat = False
        else:
            self._flat = True
        self._flat_checked = 1

        # Repo format is not flat
        if not self.is_flat():
            if self.gpg_verify and not self._has_valid_gpg_signature(local_path):
                logging.error("GPG verification failed: %s", release_file)
                logging.error("Raising GeneralRepoException!")
                raise GeneralRepoException(f"GPG verification failed: {release_file}")
            try:
                with open(release_file, "rb") as f:
                    self._release = self._parse_release_index(f.read().decode("utf-8"))
            except IOError as ex:
                logging.exception(
                    "IOError while accessing file: '%s'. Raising \
                                   GeneralRepoException!",
                    release_file,
                    exc_info=True,
                )
                raise GeneralRepoException(
                    f"IOError while accessing file: {release_file}"
                ) from ex

        # Repo format is flat
        else:
            if os.access(self._get_parent_url(local_path, 0, "InRelease"), os.R_OK):
                release_file = self._get_parent_url(local_path, 0, "InRelease")
            elif os.access(self._get_parent_url(local_path, 0, "Release"), os.R_OK):
                release_file = self._get_parent_url(local_path, 0, "Release")
            else:
                logging.error(
                    "No release file found in '%s'. Raising \
                                   GeneralRepoException.",
                    self._get_parent_url(local_path, 0),
                )
                raise GeneralRepoException(
                    f"No release file found in {self._get_parent_url(local_path, 0)}"
                )

            try:
                with open(release_file, "rb") as f:
                    release_file_content = f.read().decode("utf-8")
                    if self.gpg_verify and not self._has_valid_gpg_signature(
                        local_path
                    ):
                        logging.error(
                            "GPG verification failed: '%s'. \
                                           Raising GeneralRepoException.",
                            release_file,
                        )
                        raise GeneralRepoException(
                            f"GPG verification failed: {release_file}"
                        )
                    self._release = self._parse_release_index(release_file_content)
            except IOError as ex:
                logging.exception(
                    "IOError while accessing file: '%s'. Raising \
                                   GeneralRepoException.",
                    release_file,
                    exc_info=True,
                )
                raise GeneralRepoException(
                    f"IOError while accessing file: {release_file}"
                ) from ex

        return self._release

    def _get_release_index_from_http(self) -> Dict[str, "DpkgRepo.ReleaseEntry"]:
        # InRelease files take precedence per uyuni-rfc 00057-deb-repo-sync-gpg-check
        logging.debug("Fetching release file from local http: %s", self.url)
        resp = requests.get(
            self._get_parent_url(self.url, 2, "InRelease"),
            proxies=self.proxies,
            timeout=self.timeout,
        )
        if resp.status_code != http.HTTPStatus.OK:
            resp = requests.get(
                self._get_parent_url(self.url, 2, "Release"),
                proxies=self.proxies,
                timeout=self.timeout,
            )

        try:
            if resp.status_code not in [
                http.HTTPStatus.NOT_FOUND,
                http.HTTPStatus.OK,
                http.HTTPStatus.FORBIDDEN,
            ]:
                logging.error(
                    "Fetching release index failed with http status \
                               '%s'. Raising GeneralRepoException.",
                    resp.status_code,
                )
                raise GeneralRepoException(
                    f"HTTP error {resp.status_code} occurred while connecting to the URL"
                )

            self._flat = resp.status_code in [
                http.HTTPStatus.NOT_FOUND,
                http.HTTPStatus.FORBIDDEN,
            ]
            self._flat_checked = 1

            if (
                not self.is_flat()
                and self.gpg_verify
                and not self._has_valid_gpg_signature(resp.url, resp)
            ):
                logging.error(
                    "Repo has no valid GPG signature. Raising GeneralRepoException."
                )
                raise GeneralRepoException(f"GPG verification failed: {resp.url}")

            self._release = self._parse_release_index(resp.content.decode("utf-8"))

            if not self._release and self.is_flat():
                resp = requests.get(
                    self._get_parent_url(self.url, 0, "InRelease"),
                    proxies=self.proxies,
                    timeout=self.timeout,
                )
                if resp.status_code != http.HTTPStatus.OK:
                    resp = requests.get(
                        self._get_parent_url(self.url, 0, "Release"),
                        proxies=self.proxies,
                        timeout=self.timeout,
                    )

                if resp.status_code == http.HTTPStatus.OK:
                    if self.gpg_verify and not self._has_valid_gpg_signature(
                        resp.url, resp
                    ):
                        logging.error(
                            "Repo has no valid GPG signature. GeneralRepoException will be raised!"
                        )
                        raise GeneralRepoException(
                            f"GPG verification failed: {resp.url}"
                        )
                    self._release = self._parse_release_index(
                        resp.content.decode("utf-8")
                    )
        finally:
            resp.close()

        return self._release

    # "Packages" file parsing and verification

    def get_packages_index_raw(self) -> Tuple[str, bytes]:
        """
        Get Packages.gz or Packages.xz or Packages content, raw.

        :return: bytes of the content
        """
        if self._pkg_index[0] == "":
            for cnt_fname in [DpkgRepo.PKG_GZ, DpkgRepo.PKG_XZ, DpkgRepo.PKG_RW]:
                packages_url = self.append_index_file(cnt_fname)
                if packages_url.startswith("file://"):
                    try:
                        with open(packages_url.replace("file://", ""), "rb") as f:
                            self._pkg_index = cnt_fname, f.read()
                            break
                    except FileNotFoundError:
                        logging.debug(
                            "File not found: %s",
                            packages_url.replace("file://", ""),
                            exc_info=True,
                        )
                else:
                    resp = requests.get(
                        packages_url,
                        proxies=self.proxies,
                        timeout=self.timeout,
                    )
                    if resp.status_code == http.HTTPStatus.OK:
                        self._pkg_index = cnt_fname, resp.content
                        break
                    resp.close()

        return self._pkg_index

    def decompress_packages_index(self) -> str:
        """
        Find and return contents of Packages.gz file.

        :raises GeneralRepoException if the Packages.gz file cannot be found.
        :return: string
        """
        fname, cnt_data = self.get_packages_index_raw()
        try:
            if fname == DpkgRepo.PKG_GZ:
                cnt_data = zlib.decompress(cnt_data, 0x10 + zlib.MAX_WBITS)
            elif fname == DpkgRepo.PKG_XZ:
                cnt_data = lzma.decompress(cnt_data)
        except (zlib.error, lzma.LZMAError) as exc:
            logging.exception(
                "Exception during decompression of pkg index", exc_info=True
            )
            raise GeneralRepoException(exc) from exc
        except Exception as exc:
            logging.exception(
                "Unknown exception during decompression of \
                               pkg index. Raising GeneralRepoException",
                exc_info=True,
            )
            raise GeneralRepoException(
                f"Unhandled exception occurred while decompressing {fname}: {exc}"
            ) from exc

        return cnt_data.decode("utf-8")

    def verify_packages_index(self) -> bool:
        """
        Verify Packages index with the best available checksum algorithm.

        :return: result (boolean)
        """
        name, data = self.get_packages_index_raw()

        # If there are no packages in the repo, return True
        if (name, data) == (
            "",
            b"",
        ):
            return True

        entry = self.get_release_index().get(name)
        if entry is None:
            return False

        result = False
        for algorithm in ("sha512", "sha384", "sha256", "sha1", "md5"):
            entry_checksum = getattr(entry.checksum, algorithm, None)
            if entry_checksum:
                result = getattr(hashlib, algorithm)(data).hexdigest() == entry_checksum
                break
            else:
                continue

        return result

    def parse_packages(self) -> List[DebPackage]:
        """Parse "Packages" entries into DebPackages.

        Returns:
          A list of DebPackage objects.
        """
        ret = []
        self.cache_descriptions()
        for raw_package in self.decompress_packages_index().split("\n\n"):
            try:
                ret.append(self._parse_single_package(raw_package=raw_package))
            except ValueError:
                logger.warning("Could not parse package: %s", raw_package)
        logger.debug("Parsed packages: %s", ret)
        return ret

    def parse_packages_lazy(self) -> Generator[DebPackage, None, None]:
        """Parse "Packages" entries into DebPackages.

        Returns:
          A generator object that yields DebPackage objects.
        """
        for raw_package in self.decompress_packages_index().split("\n\n"):
            yield self._parse_single_package(raw_package=raw_package)

    def _parse_single_package(self, raw_package: str) -> DebPackage:
        """Parse a single "Packages" entry into a DebPackage."""
        package = DebPackage()
        checksums = {}
        for line in raw_package.split("\n"):
            key, value = tuple(word.strip() for word in line.split(" ", 1))
            if key == "Package:":
                package.name = value
            elif key == "Architecture:":
                package.arch = value + "-deb"
            elif key == "Version:":
                package.epoch, package.version, package.release = EpochVersionRelease(
                    evr_str=value
                ).astuple()
            elif key == "Filename:":
                package.relativepath = value
            elif key == "SHA256:":
                checksums["sha256"] = value
            elif key == "SHA1:":
                checksums["sha1"] = value
            elif key == "MD5:":
                checksums["md5"] = value
            elif key == "Description-md5:":
                package.description = self.read_package_description(value)

        # pick best checksum
        for checksum_type in ("sha256", "sha1", "md5"):
            if checksum_type in checksums:
                package.checksum_type = checksum_type
                package.checksum = checksums[checksum_type]
        if not package.is_populated():
            raise ValueError("Package is not complete: %s", package)
        return package

    def get_translation_file_raw(self) -> Tuple[str, bytes]:
        """Read an English translation file for this repo.

        Returns:
          Tuple of file name (str) and file contents (bytes)
        """
        # translation file is located in sibling directory self.url/../i18n/
        # our URL is not to the root, it's to e.g. $root/main/binary-amd64
        # FIXME: pull path from self._release (relative to release file)
        translations_raw = "", b""
        for fname in ["Translation-en.xz", "Translation-en.gz", "Translation-en"]:
            url = self._get_parent_url(self.url, depth=1, add_path=f"i18n/{fname}")
            if url.startswith("file://"):
                try:
                    with open(url.replace("file://", ""), "rb") as f:
                        translations_raw = fname, f.read()
                        break
                except FileNotFoundError:
                    logging.debug("File not found: %s", url.replace("file://", ""))
            else:
                with requests.get(
                    url, proxies=self.proxies, timeout=self.timeout
                ) as resp:
                    if resp.status_code == http.HTTPStatus.OK:
                        translations_raw = fname, resp.content
                        break
        logger.debug(
            "translations_raw fname=%s, content length=%i",
            translations_raw[0],
            len(translations_raw[1]),
        )
        return translations_raw

    def decompress_translation_file(self) -> str:
        """Decompress a raw translation file.

        Raises:
            GeneralRepoException on decompression and other errors.
        """
        # FIXME: this is 99% the same as decompress pkg index-> can we combine?
        fname, data = self.get_translation_file_raw()
        if not data:
            return ""

        try:
            if fname.endswith(".gz"):
                decompressed = zlib.decompress(data, 0x10 + zlib.MAX_WBITS)
            elif fname.endswith(".xz"):
                decompressed = lzma.decompress(data)
            else:
                decompressed = data
        except (zlib.error, lzma.LZMAError) as e:
            logging.exception("Error decompressing file %", fname, exc_info=True)
            raise GeneralRepoException from e
        except Exception as e:
            raise GeneralRepoException from e
        return decompressed.decode("utf-8")

    def cache_descriptions(self):
        """Store package descriptions in cache.

        The cache-key is the "Description-md5" as specified in "Packages" file.
        """
        if not os.path.isdir(self.description_cachedir):
            with cfg_component(component=None) as cfg:
                fileutils.makedirs(
                    self.description_cachedir,
                    user=cfg.get("httpd_user"),
                    group=cfg.get("http_group"),
                )
        for chunk in self.decompress_translation_file().split("\n\n"):
            if not chunk:
                continue
            md5, description = self._parse_translation_chunk(chunk)
            description_file = os.path.join(self.description_cachedir, md5)
            with open(description_file, "w", encoding="utf-8") as f:
                f.write(description)

    def _parse_translation_chunk(self, chunk: str) -> Tuple[str, str]:
        """Parse a description chunk into a tuple.

        Returns:
          A tuple:  (description-md5, description)
        """
        md5 = ""
        description = []
        for line in chunk.splitlines():
            if line.startswith("Package:"):
                continue
            elif line.startswith("Description-md5:"):
                md5 = line.split(" ")[-1]
            elif line.startswith("Description-en:"):
                description.append(line.split(" ", maxsplit=1)[-1])
            elif line.startswith(" "):
                description.append(line)

        return md5, "\n".join(description)

    def read_package_description(self, md5) -> str:
        """Read a package description from cache."""
        description_file = os.path.join(self.description_cachedir, md5)
        desc = ""
        if os.path.exists(description_file):
            with open(description_file, "r", encoding="utf-8") as f:
                desc = f.read()
        return desc
