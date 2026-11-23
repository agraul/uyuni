-- SPDX-FileCopyrightText: 2026 SUSE LLC
--
-- SPDX-License-Identifier: GPL-2.0-only

INSERT INTO rhnConfiguration (key, description, value, default_value)
VALUES ('SALT_PROTOCOL_ABI', 'Salt Master protocol ABI', null, null)
ON CONFLICT (key) DO NOTHING;
