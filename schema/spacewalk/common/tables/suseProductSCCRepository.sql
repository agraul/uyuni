CREATE TABLE
suseProductSCCRepository
(
    id                     NUMERIC NOT NULL primary key,
    product_id             NUMERIC NOT NULL
                                  CONSTRAINT suse_prdrepo_pid_fk
                                  REFERENCES suseProducts (id)
                                  ON DELETE CASCADE,
    root_product_id        NUMERIC NOT NULL
                                  CONSTRAINT suse_prdrepo_rpid_fk
                                  REFERENCES suseProducts (id)
                                  ON DELETE CASCADE,
    repo_id                NUMERIC NOT NULL
                                  CONSTRAINT suse_prdrepo_rid_fk
                                  REFERENCES suseSCCRepository (id)
                                  ON DELETE CASCADE,
    channel_label          VARCHAR(128) not null,
    parent_channel_label   VARCHAR(128),
    channel_name           VARCHAR(256) not null,
    mandatory              CHAR(1) DEFAULT ('N') NOT NULL
                                   CONSTRAINT suse_prdrepo_mand_ck
                                   CHECK (mandatory in ('Y', 'N')),
    update_tag             VARCHAR(128),
    gpg_key_url            VARCHAR(256),
    gpg_key_id             VARCHAR(14),
    gpg_key_fp             VARCHAR(50),
    created                TIMESTAMPTZ
                           DEFAULT (current_timestamp) NOT NULL,
    modified               TIMESTAMPTZ
                           DEFAULT (current_timestamp) NOT NULL
);

CREATE SEQUENCE suse_prdrepo_id_seq START WITH 1;

CREATE UNIQUE INDEX suse_prdrepo_pid_rpid_rid_uq
ON suseProductSCCRepository (product_id, root_product_id, repo_id)
;

CREATE INDEX suse_prdrepo_chl_idx
ON suseProductSCCRepository (channel_label)
;
