-- created by Oraschemadoc Fri Jan 22 13:39:32 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNSERVERTOKENREGS" 
   (	"TOKEN_ID" NUMBER NOT NULL ENABLE, 
	"SERVER_ID" NUMBER NOT NULL ENABLE, 
	 CONSTRAINT "RHN_SRV_REG_TOK_TID_FK" FOREIGN KEY ("TOKEN_ID")
	  REFERENCES "MIM_H1"."RHNREGTOKEN" ("ID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_SRV_REG_TOK_SID_FK" FOREIGN KEY ("SERVER_ID")
	  REFERENCES "MIM_H1"."RHNSERVER" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
