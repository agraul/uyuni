-- created by Oraschemadoc Fri Jan 22 13:39:44 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHN_HOST_CHECK_SUITES" 
   (	"HOST_PROBE_ID" NUMBER(12,0) NOT NULL ENABLE, 
	"SUITE_ID" NUMBER(12,0) NOT NULL ENABLE, 
	 CONSTRAINT "RHN_HSTCK_SUITE_ID_PROBE_ID_PK" PRIMARY KEY ("HOST_PROBE_ID", "SUITE_ID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_HSTCK_CKSUT_SUITE_ID_FK" FOREIGN KEY ("SUITE_ID")
	  REFERENCES "MIM_H1"."RHN_CHECK_SUITES" ("RECID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_HSTCK_HSTPB_PROBE_ID_FK" FOREIGN KEY ("HOST_PROBE_ID")
	  REFERENCES "MIM_H1"."RHN_HOST_PROBE" ("PROBE_ID") ON DELETE CASCADE ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
