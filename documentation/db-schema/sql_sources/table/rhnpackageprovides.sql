-- created by Oraschemadoc Fri Jan 22 13:39:22 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNPACKAGEPROVIDES" 
   (	"PACKAGE_ID" NUMBER NOT NULL ENABLE, 
	"CAPABILITY_ID" NUMBER NOT NULL ENABLE, 
	"SENSE" NUMBER DEFAULT (0) NOT NULL ENABLE, 
	"CREATED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	"MODIFIED" DATE DEFAULT (sysdate) NOT NULL ENABLE, 
	 CONSTRAINT "RHN_PKG_PROVIDES_PACKAGE_FK" FOREIGN KEY ("PACKAGE_ID")
	  REFERENCES "MIM_H1"."RHNPACKAGE" ("ID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_PKG_PROVIDES_CAPABILITY_FK" FOREIGN KEY ("CAPABILITY_ID")
	  REFERENCES "MIM_H1"."RHNPACKAGECAPABILITY" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
