-- created by Oraschemadoc Fri Jan 22 13:39:43 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_COMMAND_TARGET" 
   (	"RECID" NUMBER(12,0) NOT NULL ENABLE, 
	"TARGET_TYPE" VARCHAR2(10) NOT NULL ENABLE, 
	"CUSTOMER_ID" NUMBER(12,0) NOT NULL ENABLE, 
	 CONSTRAINT "CMDTG_TARGET_TYPE_CK" CHECK (target_type in ( 'cluster' , 'node' )) ENABLE, 
	 CONSTRAINT "RHN_CMDTG_RECID_TARGET_TYPE_PK" PRIMARY KEY ("RECID", "TARGET_TYPE")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_CMDTG_CSTMR_CUSTOMER_ID_FK" FOREIGN KEY ("CUSTOMER_ID")
	  REFERENCES "MIM_H1"."WEB_CUSTOMER" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
