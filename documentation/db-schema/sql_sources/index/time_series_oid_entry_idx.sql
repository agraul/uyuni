-- created by Oraschemadoc Fri Jan 22 13:40:38 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE INDEX "MIM_H1"."TIME_SERIES_OID_ENTRY_IDX" ON "MIM_H1"."TIME_SERIES" ("O_ID", "ENTRY_TIME") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT)
  TABLESPACE "DATA_TBS" 
 
/
