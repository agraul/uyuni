-- created by Oraschemadoc Fri Jan 22 13:39:15 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNGRAILCOMPONENTS" 
   (	"ID" NUMBER, 
	"COMPONENT_PKG" VARCHAR2(64) NOT NULL ENABLE, 
	"COMPONENT_MODE" VARCHAR2(64) NOT NULL ENABLE, 
	"CONFIG_MODE" VARCHAR2(64), 
	"COMPONENT_LABEL" VARCHAR2(128), 
	"ROLE_REQUIRED" NUMBER, 
	 CONSTRAINT "RHN_GRAIL_COMP_PK" PRIMARY KEY ("ID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_GRAIL_COMP_ROLE_TYPE_FK" FOREIGN KEY ("ROLE_REQUIRED")
	  REFERENCES "MIM_H1"."RHNUSERGROUPTYPE" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
