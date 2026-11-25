-- SPDX-FileCopyrightText: 2026 SUSE LLC
--
-- SPDX-License-Identifier: GPL-2.0-only

ALTER TABLE suseManagerInfo ADD COLUMN IF NOT EXISTS salt_protocol_abi VARCHAR(32);

-- the value was briefly stored in rhnConfiguration during development
DELETE FROM rhnConfiguration WHERE key = 'SALT_PROTOCOL_ABI';
