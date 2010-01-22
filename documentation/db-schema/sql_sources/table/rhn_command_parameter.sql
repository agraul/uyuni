-- created by Oraschemadoc Fri Jan 22 13:39:41 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_COMMAND_PARAMETER" 
   (	"COMMAND_ID" NUMBER(12,0) NOT NULL ENABLE, 
	"PARAM_NAME" VARCHAR2(40) NOT NULL ENABLE, 
	"PARAM_TYPE" VARCHAR2(10) DEFAULT ('config') NOT NULL ENABLE, 
	"DATA_TYPE_NAME" VARCHAR2(10) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(80) NOT NULL ENABLE, 
	"MANDATORY" CHAR(1) DEFAULT ('0') NOT NULL ENABLE, 
	"DEFAULT_VALUE" VARCHAR2(1024), 
	"MIN_VALUE" NUMBER, 
	"MAX_VALUE" NUMBER, 
	"FIELD_ORDER" NUMBER NOT NULL ENABLE, 
	"FIELD_WIDGET_NAME" VARCHAR2(20) NOT NULL ENABLE, 
	"FIELD_VISIBLE_LENGTH" NUMBER, 
	"FIELD_MAXIMUM_LENGTH" NUMBER, 
	"FIELD_VISIBLE" CHAR(1) DEFAULT ('1') NOT NULL ENABLE, 
	"DEFAULT_VALUE_VISIBLE" CHAR(1) DEFAULT ('1') NOT NULL ENABLE, 
	"LAST_UPDATE_USER" VARCHAR2(40), 
	"LAST_UPDATE_DATE" DATE, 
	 CONSTRAINT "RHN_CPARM_ID_PARM_NAME_PK" PRIMARY KEY ("COMMAND_ID", "PARAM_NAME")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_CPARM_ID_P_NAME_P_TYPE_UQ" UNIQUE ("COMMAND_ID", "PARAM_NAME", "PARAM_TYPE")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_CPARM_ID_FIELD_ORDE_UQ" UNIQUE ("COMMAND_ID", "FIELD_ORDER")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_CPARM_CMD_COMMAND_ID_FK" FOREIGN KEY ("COMMAND_ID")
	  REFERENCES "MIM_H1"."RHN_COMMAND" ("RECID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_CPARM_SDTYP_NAME_FK" FOREIGN KEY ("DATA_TYPE_NAME")
	  REFERENCES "MIM_H1"."RHN_SEMANTIC_DATA_TYPE" ("NAME") ENABLE, 
	 CONSTRAINT "RHN_CPARM_WDGT_FLD_WDGT_N_FK" FOREIGN KEY ("FIELD_WIDGET_NAME")
	  REFERENCES "MIM_H1"."RHN_WIDGET" ("NAME") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
