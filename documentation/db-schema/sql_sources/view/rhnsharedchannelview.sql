-- created by Oraschemadoc Fri Jan 22 13:40:45 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE OR REPLACE FORCE VIEW "MIM_H1"."RHNSHAREDCHANNELVIEW" ("ID", "PARENT_CHANNEL", "ORG_ID", "CHANNEL_ARCH_ID", "LABEL", "BASEDIR", "NAME", "SUMMARY", "DESCRIPTION", "PRODUCT_NAME_ID", "GPG_KEY_URL", "GPG_KEY_ID", "GPG_KEY_FP", "END_OF_LIFE", "RECEIVING_UPDATES", "LAST_MODIFIED", "CHANNEL_PRODUCT_ID", "CREATED", "MODIFIED", "CHANNEL_ACCESS", "ORG_TRUST_ID") AS 
  SELECT
   CH.ID,
   CH.PARENT_CHANNEL,
   CH.ORG_ID,
   CH.CHANNEL_ARCH_ID,
   CH.LABEL,
   CH.BASEDIR,
   CH.NAME,
   CH.SUMMARY,
   CH.DESCRIPTION,
   CH.PRODUCT_NAME_ID,
   CH.GPG_KEY_URL,
   CH.GPG_KEY_ID,
   CH.GPG_KEY_FP,
   CH.END_OF_LIFE,
   CH.RECEIVING_UPDATES,
   CH.LAST_MODIFIED,
   CH.CHANNEL_PRODUCT_ID,
   CH.CREATED,
   CH.MODIFIED,
   CH.CHANNEL_ACCESS,
   TR.ORG_TRUST_ID
FROM RHNCHANNEL CH,
     RHNTRUSTEDORGS TR
WHERE CH.ORG_ID = TR.ORG_ID AND
      CH.CHANNEL_ACCESS = 'public'
UNION
SELECT
   CH.ID,
   CH.PARENT_CHANNEL,
   CH.ORG_ID,
   CH.CHANNEL_ARCH_ID,
   CH.LABEL,
   CH.BASEDIR,
   CH.NAME,
   CH.SUMMARY,
   CH.DESCRIPTION,
   CH.PRODUCT_NAME_ID,
   CH.GPG_KEY_URL,
   CH.GPG_KEY_ID,
   CH.GPG_KEY_FP,
   CH.END_OF_LIFE,
   CH.RECEIVING_UPDATES,
   CH.LAST_MODIFIED,
   CH.CHANNEL_PRODUCT_ID,
   CH.CREATED,
   CH.MODIFIED,
   CH.CHANNEL_ACCESS,
   TR.ORG_TRUST_ID
FROM RHNCHANNEL CH,
     RHNCHANNELTRUST TR
WHERE CH.ID = TR.CHANNEL_ID AND
      CH.CHANNEL_ACCESS = 'protected'

 
/
