-- created by Oraschemadoc Fri Jan 22 13:39:31 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNSERVERPROFILEPACKAGE" 
   (	"SERVER_PROFILE_ID" NUMBER NOT NULL ENABLE, 
	"NAME_ID" NUMBER NOT NULL ENABLE, 
	"EVR_ID" NUMBER NOT NULL ENABLE, 
	"PACKAGE_ARCH_ID" NUMBER, 
	 CONSTRAINT "RHN_SPROFILE_SPID_FK" FOREIGN KEY ("SERVER_PROFILE_ID")
	  REFERENCES "MIM_H1"."RHNSERVERPROFILE" ("ID") ON DELETE CASCADE ENABLE, 
	 CONSTRAINT "RHN_SPROFILE_NID_FK" FOREIGN KEY ("NAME_ID")
	  REFERENCES "MIM_H1"."RHNPACKAGENAME" ("ID") ENABLE, 
	 CONSTRAINT "RHN_SPROFILE_EVRID_FK" FOREIGN KEY ("EVR_ID")
	  REFERENCES "MIM_H1"."RHNPACKAGEEVR" ("ID") ENABLE, 
	 CONSTRAINT "RHN_SPROFILE_PACKAGE_FK" FOREIGN KEY ("PACKAGE_ARCH_ID")
	  REFERENCES "MIM_H1"."RHNPACKAGEARCH" ("ID") ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE ROW MOVEMENT 
 
/
