-- created by Oraschemadoc Fri Jan 22 13:39:58 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE UNIQUE INDEX "MIM_H1"."RHN_AT_AID_FTID_TTID_UQ" ON "MIM_H1"."RHNACTIONTRANSACTIONS" ("ACTION_ID", "FROM_TRANS_ID", "TO_TRANS_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS" 
 
/
