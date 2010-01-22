-- created by Oraschemadoc Fri Jan 22 13:39:08 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNCONFIGREVISION" 
   (	"ID" NUMBER NOT NULL ENABLE, 
	"REVISION" NUMBER NOT NULL ENABLE, 
	"CONFIG_FILE_ID" NUMBER NOT NULL ENABLE, 
	"CONFIG_CONTENT_ID" NUMBER NOT NULL ENABLE, 
	"CONFIG_INFO_ID" NUMBER NOT NULL ENABLE, 
	"DELIM_START" VARCHAR2(16) NOT NULL ENABLE, 
	"DELIM_END" VARCHAR2(16) NOT NULL ENABLE, 
	"CREATED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	"MODIFIED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	"CONFIG_FILE_TYPE_ID" NUMBER DEFAULT (1) NOT NULL ENABLE, 
	"CHANGED_BY_ID" NUMBER DEFAULT (null), 
	 CONSTRAINT "RHN_CONFREVISION_ID_PK" PRIMARY KEY ("ID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_CONFREVISION_CFID_FK" FOREIGN KEY ("CONFIG_FILE_ID")
	  REFERENCES "MIM_H1"."RHNCONFIGFILE" ("ID") ENABLE, 
	 CONSTRAINT "RHN_CONFREVISION_CCID_FK" FOREIGN KEY ("CONFIG_CONTENT_ID")
	  REFERENCES "MIM_H1"."RHNCONFIGCONTENT" ("ID") ENABLE, 
	 CONSTRAINT "RHN_CONFREVISION_CIID_FK" FOREIGN KEY ("CONFIG_INFO_ID")
	  REFERENCES "MIM_H1"."RHNCONFIGINFO" ("ID") ENABLE, 
	 CONSTRAINT "RHN_CONF_REV_CFTI_FK" FOREIGN KEY ("CONFIG_FILE_TYPE_ID")
	  REFERENCES "MIM_H1"."RHNCONFIGFILETYPE" ("ID") ENABLE, 
	 CONSTRAINT "RHN_CONFREVISION_CID_FK" FOREIGN KEY ("CHANGED_BY_ID")
	  REFERENCES "MIM_H1"."WEB_CONTACT" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
