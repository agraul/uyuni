-- created by Oraschemadoc Fri Jan 22 13:39:57 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE INDEX "MIM_H1"."RHN_APPINST_SESSN_UID_IID_IDX" ON "MIM_H1"."RHNAPPINSTALLSESSION" ("USER_ID", "INSTANCE_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS" 
 
/
