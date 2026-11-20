# Exclude Incompatible Salt Bundle Packages From Client Repositories

## Problem

Salt Minion packages (salt-minion or venv-salt-minion) must not have a larger major version than the
running Salt master. The auth version (part of the transport layer) on the Minion must not be larger
than the auth version on the Salt master. It may be lower, although that causes issues when Salt
master sets `minimum_auth_version` to a higher version than the Minion speaks.

In Uyuni, we can control which Salt Minion packages are installable by clients since we control the
repositories.

## Solution Requirements

- Incompatible packages are part of the channels, not orphans
- As soon as the Salt Master ABI changes (e.g. after running `mgradm upgrade`), compatibility of
  Salt Minion packages is re-evaluated
- Newly synced salt Minion packages are not installable if they are not compatible.
- Incompatible Salt Minion packages are not part of bootstrap and normal client
  repository metadata
- Incompatible Salt Minion packages are marked as uninstallable in the WebUI.
- Minor versions are not important, they are compatible unless the auth version changes. For other
  cases, we'll have a "tiebreaker" we can bump in special circumstances.
- Comparison rule: A Salt Minion package is compatible if minion.major <= master.major and
  minion.auth <= master.auth, and, if both major and auth are equal, minion.tiebreaker <= master.tiebreaker.
  This is not an RPM version comparison.

## Plan

- Salt packages (salt-minion, python3X-salt, venv-salt-minion, etc.) provide a new symbol:
   `salt-protocol-abi = <major version>.<auth version>.<tiebreaker>`
- Salt packages that don't have the provides are assumed compatible (backwards compatibility/current behavior)
- We add a new grain `__suse_reserved_protocol_abi`. The `salt-protocol-abi` RPM provides is checked
  against the grain value at build time to prevent drift.
- Uyuni queries the Salt Master protocol abi with an API call equivalent to `salt-run salt.cmd grains.get __suse_reserved_protocol_abi`
- When the grain on the Salt Master can't be determined, the previously determined value is used. If
  there is no previous value, all Salt Minion packages are deemed compatible.
- We're implementing the change in Uyuni first to evaluate the mechanism. It will be backported to Manager-5.2 later.
- Before building repository metadata, Uyuni filters out all packages providing `salt-protocol-abi` that is not compatible with the Salt Master.
- In Hub scenarios, each Peripheral computes which Minion packages to hold back based on the protocol abi of its Salt Master.
- On container startup, a script checks the Salt Master protocol ABI and saves it in the database

## Out of Scope
- Warn when a Minion's auth version is less than `minimum_auth_version` on the Master
- Minions running an incompatible version (Salt logs contain errors)
- Admin override (later)
- Restricting direct package downloads. The packages are just not part of repository metadata.
- Multi-Linux Manager 5.1
- Live-update of Salt Master protocol ABI. That will only be needed when Salt Master runs in a different container
