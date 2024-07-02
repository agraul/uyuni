CREATE TABLE rhnPackageChecksum(
    package_id  NUMERIC CONSTRAINT rhn_pcs_pid_fk
                        REFERENCES rhnPackage (id),
    package_source_id NUMERIC CONSTRAINT rhn_spcs_pid_fk
                        REFERENCES rhnPackageSource (id),
    checksum_id NUMERIC NOT NULL
                    CONSTRAINT rhn_pcs_csid_fk
                        REFERENCES rhnChecksum (id),
    created     TIMESTAMPTZ
                    DEFAULT (current_timestamp) NOT NULL,
    modified    TIMESTAMPTZ
                    DEFAULT (current_timestamp) NOT NULL,
    -- make sure either package_source_id or package_id is not null
    check(
      ((package_source_id is not null)::integer +
       (package_id is not null)::integer
      ) = 1
    )
);

CREATE UNIQUE INDEX rhn_pc_pcs_uq ON rhnPackageChecksum (package_id, checksum_id);
CREATE UNIQUE INDEX rhn_pc_pscs_uq ON rhnPackageChecksum (package_source_id, checksum_id);
