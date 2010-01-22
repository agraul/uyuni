-- created by Oraschemadoc Fri Jan 22 13:39:18 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNKSTREEFILE" 
   (	"KSTREE_ID" NUMBER NOT NULL ENABLE, 
	"RELATIVE_FILENAME" VARCHAR2(256) NOT NULL ENABLE, 
	"CHECKSUM_ID" NUMBER NOT NULL ENABLE, 
	"FILE_SIZE" NUMBER NOT NULL ENABLE, 
	"LAST_MODIFIED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	"CREATED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	"MODIFIED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	 CONSTRAINT "RHN_KSTREEFILE_KID_FK" FOREIGN KEY ("KSTREE_ID")
	  REFERENCES "MIM_H1"."RHNKICKSTARTABLETREE" ("ID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_KSTREEFILE_CHSUM_FK" FOREIGN KEY ("CHECKSUM_ID")
	  REFERENCES "MIM_H1"."RHNCHECKSUM" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
