-- created by Oraschemadoc Fri Jan 22 13:39:34 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE TABLE "MIM_H1"."RHNSOLARISPACKAGE" 
   (	"PACKAGE_ID" NUMBER, 
	"CATEGORY" VARCHAR2(2048) NOT NULL ENABLE, 
	"PKGINFO" VARCHAR2(4000), 
	"PKGMAP" BLOB, 
	"INTONLY" CHAR(1) DEFAULT ('N'), 
	 CONSTRAINT "RHN_SOLARIS_PKG_IO_CK" CHECK (intonly in ( 'Y' , 'N' )) ENABLE, 
	 CONSTRAINT "RHN_SOLARIS_PKG_PID_PK" PRIMARY KEY ("PACKAGE_ID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS"  ENABLE, 
	 CONSTRAINT "RHN_SOLARIS_PKG_PID_FK" FOREIGN KEY ("PACKAGE_ID")
	  REFERENCES "MIM_H1"."RHNPACKAGE" ("ID") ON DELETE CASCADE ENABLE
   ) PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS" 
 LOB ("PKGMAP") STORE AS BASICFILE (
  TABLESPACE "DATA_TBS" ENABLE STORAGE IN ROW CHUNK 8192 RETENTION 
  NOCACHE LOGGING 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT))  ENABLE ROW MOVEMENT 
 
/
