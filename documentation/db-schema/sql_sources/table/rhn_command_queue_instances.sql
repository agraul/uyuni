-- created by Oraschemadoc Fri Jan 22 13:39:42 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_COMMAND_QUEUE_INSTANCES" 
   (	"RECID" NUMBER(12,0) NOT NULL ENABLE, 
	"COMMAND_ID" NUMBER(12,0) NOT NULL ENABLE, 
	"NOTES" VARCHAR2(2000), 
	"DATE_SUBMITTED" DATE NOT NULL ENABLE, 
	"EXPIRATION_DATE" DATE NOT NULL ENABLE, 
	"NOTIFY_EMAIL" VARCHAR2(50), 
	"TIMEOUT" NUMBER(5,0), 
	"LAST_UPDATE_USER" VARCHAR2(40), 
	"LAST_UPDATE_DATE" DATE, 
	 CONSTRAINT "RHN_CQINS_RECID_PK" PRIMARY KEY ("RECID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_CQINS_CQCMD_COMMAND_ID_FK" FOREIGN KEY ("COMMAND_ID")
	  REFERENCES "MIM_H1"."RHN_COMMAND_QUEUE_COMMANDS" ("RECID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
