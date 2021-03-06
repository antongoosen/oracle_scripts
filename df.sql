-----------------------------------------------------
--  This script lists tablespace space statistics  --
-----------------------------------------------------

set feed off head off ver off
# Hello Coen
column name format a16
select name
from v$database;
undef name

prompt

set serverout on echo off ver off timing on feed off head on

declare
 cnt1 number;
 cnt2 number;
 cnt3 number;
 cnt4 number;
 war  number;
 bla  varchar2(20);
begin
 dbms_output.enable(20000);
 dbms_output.put_line('Database size info');
 dbms_output.put_line('Tablespace              SEGS   FRAGS      SIZE      FREE       USED');
 dbms_output.put_line('---------------------------------------------------------------------');
 for c1 in (select tablespace_name, status from dba_tablespaces order by 1)
 loop

   select sum(bytes/1048576) into cnt1
   from
   	(	select tablespace_name, bytes from dba_data_files
		union all
		select tablespace_name, bytes from dba_temp_files)
   where tablespace_name = c1.tablespace_name;

   select count(*) into cnt4
   from dba_segments
   where tablespace_name = c1.tablespace_name;

   select free into cnt2
   from (	(select b.tablespace_name, nvl(sum(a.bytes/1048576),0) free
		from dba_free_space a,
		dba_tablespaces b
		where	a.tablespace_name(+) = b.tablespace_name
		and	b.contents != 'TEMPORARY'
		group by b.tablespace_name)
		union
		select	t.tablespace_name,
			d.TOTAL_M - sum(nvl(a.used_blocks,1) * d.block_size)/1048576 free
		from	v$sort_segment a,
			(	SELECT	b.name tablespace_name,
					c.block_size,
					sum(c.bytes)/1048576 TOTAL_M
				FROM	v$tablespace b,
					v$tempfile c
				WHERE	b.ts#= c.ts#
				GROUP	BY b.name,
					c.block_size) d,
			dba_temp_files t
		where	t.tablespace_name = d.tablespace_name
		and	a.tablespace_name(+) = t.tablespace_name
		group 	by t.tablespace_name,
			d.TOTAL_M,
			t.file_name)
   where tablespace_name = c1.tablespace_name;

   select count(*) into cnt3
   from dba_free_space
   where tablespace_name = c1.tablespace_name;

   war := (cnt2/cnt1)*100;
   select status into bla from dba_tablespaces where tablespace_name = c1.tablespace_name;

   dbms_output.put(rpad(c1.tablespace_name,20)||':'||lpad(cnt4,7)||lpad(cnt3,8)||lpad(round(cnt1),10)||lpad(round(cnt2),10)||lpad(round(100-((cnt2/cnt1)*100)),10)||'%');
   if bla = 'OFFLINE' then
      dbms_output.put_line('  -- OFFLINE --');
   else if war < 10 then
	dbms_output.put_line(' !!!');
	for c2 in (select file_name, bytes from dba_data_files where tablespace_name = c1.tablespace_name order by 2 asc)
  	loop
	  dbms_output.put_line(' ++ alter database datafile');
	  dbms_output.put_line(' ++ '''||c2.file_name||''' resize '||round((c2.bytes/1048576)+1000)||'M;');
	  dbms_output.put_line(' ++ was --> '||round(c2.bytes/1048576)||'M');
	end loop;
   else
	dbms_output.put_line(' ');
   end if;
   end if;
 end loop;
end;
/
set timing off feedback on
prompt
prompt Now run @min_free to calculate the amount of space needed to be added for a X%
prompt of free space
prompt
