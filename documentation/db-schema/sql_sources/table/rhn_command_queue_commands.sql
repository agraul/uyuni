-- created by Oraschemadoc Fri Jan 22 13:39:41 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_COMMAND_QUEUE_COMMANDS" 
   (	"RECID" NUMBER(12,0) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(40) NOT NULL ENABLE, 
	"NOTES" VARCHAR2(2000), 
	"COMMAND_LINE" VARCHAR2(2000) NOT NULL ENABLE, 
	"PERMANENT" CHAR(1) NOT NULL ENABLE, 
	"RESTARTABLE" CHAR(1) NOT NULL ENABLE, 
	"EFFECTIVE_USER" VARCHAR2(40) NOT NULL ENABLE, 
	"EFFECTIVE_GROUP" VARCHAR2(40) NOT NULL ENABLE, 
	"LAST_UPDATE_USER" VARCHAR2(40), 
	"LAST_UPDATE_DATE" DATE, 
	 CONSTRAINT "RHN_CQCMD_RECID_PK" PRIMARY KEY ("RECID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
