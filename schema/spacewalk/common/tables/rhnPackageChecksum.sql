CREATE TABLE rhnPackageChecksum
(
    package_id  NUMERIC NOT NULL
                    CONSTRAINT rhn_pcs_pid_fk
                        REFERENCES rhnPackage (id),
    checksum_id NUMERIC NOT NULL
                    CONSTRAINT rhn_pcs_csid_fk
                        REFERENCES rhnChecksum (id),
    created     TIMESTAMPTZ
                    DEFAULT (current_timestamp) NOT NULL,
    modified    TIMSTAMPTZ
                    DEFAULT (current_timestamp) NOT NULL
);

CREATE UNIQUE INDEX rhn_pc_pcs_uq ON rhnPackageChecksum (package_id, checksum_id);
