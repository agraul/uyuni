CREATE TABLE IF NOT EXISTS rhnPackageChecksum(
    package_id  NUMERIC CONSTRAINT rhn_pcs_pid_fk
                        REFERENCES rhnPackage (id),
    package_source_id NUMERIC CONSTRAINT rhn_pcs_spid_fk
                        REFERENCES rhnPackageSource (id),
    checksum_id NUMERIC NOT NULL
                    CONSTRAINT rhn_pcs_csid_fk
                        REFERENCES rhnChecksum (id),
    created     TIMESTAMPTZ
                    DEFAULT (current_timestamp) NOT NULL,
    modified    TIMESTAMPTZ
                    DEFAULT (current_timestamp) NOT NULL,
    check(
      -- make sure either package_source_id or package_id is not null
      ((package_source_id is not null)::integer +
       (package_id is not null)::integer
      ) = 1
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS rhn_pc_pcs_uq
    ON rhnPackageChecksum (package_id, checksum_id);
CREATE UNIQUE INDEX IF NOT EXISTS rhn_pc_pscs_uq
    ON rhnPackageChecksum (package_source_id, checksum_id);

-- FIXME: Fails with
-- ERROR:  cannot drop column checksum_id of table rhnpackage because other objects depend on it
-- DETAIL:  view susepackageexcludingpartofptf depends on column checksum_id of table rhnpackage
-- view rhnchannelnewestpackageview depends on view susepackageexcludingpartofptf
ALTER TABLE rhnPackage
    DROP COLUMN IF EXISTS checksum_id;
ALTER TABLE rhnPackageSource
    DROP COLUMN IF EXISTS checksum_id;
