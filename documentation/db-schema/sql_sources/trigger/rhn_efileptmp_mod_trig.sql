-- created by Oraschemadoc Fri Jan 22 13:40:58 2010
-- visit http://www.yarpen.cz/oraschemadoc/ for more info

  CREATE OR REPLACE TRIGGER "MIM_H1"."RHN_EFILEPTMP_MOD_TRIG" 
before insert or update on rhnErrataFilePackageTmp
for each row
begin
	:new.modified := sysdate;
end rhn_efilep_mod_trig;
ALTER TRIGGER "MIM_H1"."RHN_EFILEPTMP_MOD_TRIG" ENABLE
 
/
