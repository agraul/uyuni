-- created by Oraschemadoc Fri Jan 22 13:39:39 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNVIRTUALINSTANCEINFO" 
   (	"NAME" VARCHAR2(128), 
	"INSTANCE_ID" NUMBER NOT NULL ENABLE, 
	"INSTANCE_TYPE" NUMBER NOT NULL ENABLE, 
	"MEMORY_SIZE_K" NUMBER, 
	"VCPUS" NUMBER, 
	"STATE" NUMBER NOT NULL ENABLE, 
	"CREATED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	"MODIFIED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	 CONSTRAINT "RHN_VII_VIID_FK" FOREIGN KEY ("INSTANCE_ID")
	  REFERENCES "MIM_H1"."RHNVIRTUALINSTANCE" ("ID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_VII_IT_FK" FOREIGN KEY ("INSTANCE_TYPE")
	  REFERENCES "MIM_H1"."RHNVIRTUALINSTANCETYPE" ("ID") ENABLE, 
	 CONSTRAINT "RHN_VII_STATE_FK" FOREIGN KEY ("STATE")
	  REFERENCES "MIM_H1"."RHNVIRTUALINSTANCESTATE" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
