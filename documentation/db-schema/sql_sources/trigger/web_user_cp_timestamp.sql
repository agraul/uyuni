-- created by Oraschemadoc Fri Jan 22 13:41:02 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE OR REPLACE TRIGGER "MIM_H1"."WEB_USER_CP_TIMESTAMP" 
BEFORE INSERT OR UPDATE ON web_user_contact_permission
FOR EACH ROW
BEGIN
  :new.modified := sysdate;
END;
ALTER TRIGGER "MIM_H1"."WEB_USER_CP_TIMESTAMP" ENABLE
 
/
