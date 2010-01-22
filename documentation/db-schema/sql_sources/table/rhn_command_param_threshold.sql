-- created by Oraschemadoc Fri Jan 22 13:39:41 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_COMMAND_PARAM_THRESHOLD" 
   (	"COMMAND_ID" NUMBER(12,0) NOT NULL ENABLE, 
	"PARAM_NAME" VARCHAR2(40) NOT NULL ENABLE, 
	"PARAM_TYPE" VARCHAR2(10) NOT NULL ENABLE, 
	"THRESHOLD_TYPE_NAME" VARCHAR2(10) NOT NULL ENABLE, 
	"THRESHOLD_METRIC_ID" VARCHAR2(40) NOT NULL ENABLE, 
	"LAST_UPDATE_USER" VARCHAR2(40), 
	"LAST_UPDATE_DATE" DATE, 
	"COMMAND_CLASS" VARCHAR2(255) NOT NULL ENABLE, 
	 CONSTRAINT "RHN_COPTR_PARAM_TYPE_CK" CHECK (param_type = 'threshold') ENABLE, 
	 CONSTRAINT "RHN_COPTR_ID_P_NAME_P_TYPE_PK" PRIMARY KEY ("COMMAND_ID", "PARAM_NAME", "PARAM_TYPE")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_COPTR_CMD_ID_CMD_CL_FK" FOREIGN KEY ("COMMAND_ID", "COMMAND_CLASS")
	  REFERENCES "MIM_H1"."RHN_COMMAND" ("RECID", "COMMAND_CLASS") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_COPTR_M_THR_M_CMD_CL_FK" FOREIGN KEY ("COMMAND_CLASS", "THRESHOLD_METRIC_ID")
	  REFERENCES "MIM_H1"."RHN_METRICS" ("COMMAND_CLASS", "METRIC_ID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_COPTR_THRTP_THRES_TYPE_FK" FOREIGN KEY ("THRESHOLD_TYPE_NAME")
	  REFERENCES "MIM_H1"."RHN_THRESHOLD_TYPE" ("NAME") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
