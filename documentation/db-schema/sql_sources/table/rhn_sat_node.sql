-- created by Oraschemadoc Fri Jan 22 13:39:48 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_SAT_NODE" 
   (	"RECID" NUMBER(12,0) NOT NULL ENABLE, 
	"SERVER_ID" NUMBER, 
	"TARGET_TYPE" VARCHAR2(10) DEFAULT ('node') NOT NULL ENABLE, 
	"LAST_UPDATE_USER" VARCHAR2(40), 
	"LAST_UPDATE_DATE" DATE, 
	"MAC_ADDRESS" VARCHAR2(17) NOT NULL ENABLE, 
	"MAX_CONCURRENT_CHECKS" NUMBER(4,0), 
	"SAT_CLUSTER_ID" NUMBER(12,0) NOT NULL ENABLE, 
	"IP" VARCHAR2(15), 
	"SCHED_LOG_LEVEL" NUMBER(4,0) DEFAULT (0) NOT NULL ENABLE, 
	"SPUT_LOG_LEVEL" NUMBER(4,0) DEFAULT (0) NOT NULL ENABLE, 
	"DQ_LOG_LEVEL" NUMBER(4,0) DEFAULT (0) NOT NULL ENABLE, 
	"SCOUT_SHARED_KEY" VARCHAR2(64) NOT NULL ENABLE, 
	 CONSTRAINT "RHN_SATND_TARGET_TYPE_CK" CHECK (target_type in ( 'node' )) ENABLE, 
	 CONSTRAINT "RHN_SATND_RECID_PK" PRIMARY KEY ("RECID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_SATND_SID_FK" FOREIGN KEY ("SERVER_ID")
	  REFERENCES "MIM_H1"."RHNSERVER" ("ID") ENABLE, 
	 CONSTRAINT "RHN_SATND_CMDTG_RID_TAR_TY_FK" FOREIGN KEY ("RECID", "TARGET_TYPE")
	  REFERENCES "MIM_H1"."RHN_COMMAND_TARGET" ("RECID", "TARGET_TYPE") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_SATND_SATCL_SAT_CL_ID_FK" FOREIGN KEY ("SAT_CLUSTER_ID")
	  REFERENCES "MIM_H1"."RHN_SAT_CLUSTER" ("RECID") ON DELETE CASCADE ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
