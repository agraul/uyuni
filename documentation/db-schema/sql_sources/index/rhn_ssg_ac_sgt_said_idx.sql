-- created by Oraschemadoc Fri Jan 22 13:40:31 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE INDEX "MIM_H1"."RHN_SSG_AC_SGT_SAID_IDX" ON "MIM_H1"."RHNSERVERSERVERGROUPARCHCOMPAT" ("SERVER_GROUP_TYPE", "SERVER_ARCH_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 NOLOGGING COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS" 
 
/
