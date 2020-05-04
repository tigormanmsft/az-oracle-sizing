REM ================================================================================
REM Name:       busiest_awr.sql
REM Type:       Oracle SQL script
REM Date:       27-April 2020
REM From:       Americas Customer Engineering team (CET) - Microsoft
REM
REM Copyright and license:
REM
REM     Licensed under the Apache License, Version 2.0 (the "License"); you may
REM     not use this file except in compliance with the License.
REM
REM     You may obtain a copy of the License at
REM
REM             http://www.apache.org/licenses/LICENSE-2.0
REM
REM     Unless required by applicable law or agreed to in writing, software
REM     distributed under the License is distributed on an "AS IS" basis,
REM     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM
REM     See the License for the specific language governing permissions and
REM     limitations under the License.
REM
REM     Copyright (c) 2020 by Microsoft.  All rights reserved.
REM
REM Ownership and responsibility:
REM
REM     This script is offered without warranty by Microsoft Customer Engineering.
REM     Anyone using this script accepts full responsibility for use, effect,
REM     and maintenance.  Please do not contact Microsoft or Oracle support unless
REM     there is a problem with a supported SQL or SQL*Plus command.
REM
REM Description:
REM
REM     SQL*Plus script to find the top 5 busiest AWR snapshots within the horizon
REM     of all information stored within the Oracle AWR repository, based on the
REM     statistics "physical reads" (a.k.a. physical I/O or "PIO") and "CPU used
REM     by this session" (a.k.a. cumulative session-level CPU usage).
REM
REM Modifications:
REM     TGorman 27apr20 v0.1 written
REM     TGorman 04may20 v0.2    removed NTILE, using only ROW_NUMBER now...
REM ================================================================================
set pages 100 lines 80 verify off echo off feedback 6 timing off recsep off
col dbid heading 'DB ID'
col con_id format 90 heading 'Con|ID'
col instance_number format 90 heading 'I#'
col snap_id heading 'AWR|Snap ID'
col begin_time format a12 heading 'Beginning|time' word_wrap
col end_time format a12 heading 'Ending|time' word_wrap
col pio heading 'Physical|Reads|(PIO)'
col cpu heading 'CPU used by|this session|(CPU)'
spool busiest_awr
select  s.dbid, s.instance_number, s.con_id, s.snap_id,
        trim(to_char(s.begin_interval_time,'DD-MON-YYYY HH24:MI:SS')) begin_time,
        trim(to_char(s.end_interval_time,'DD-MON-YYYY HH24:MI:SS')) end_time,
        pio, cpu
from    (select dbid, instance_number, con_id, snap_id, pio, cpu, rn
         from   (select dbid, instance_number, con_id, snap_id, pio, cpu, row_number() over (order by sortby desc) rn
                 from   (select dbid, instance_number, con_id, snap_id, sum(pio) pio, sum(cpu) cpu, sum(sortby) sortby
                         from   (select dbid, instance_number, con_id, snap_id, stat_name, value pio, 0 cpu, (value*10) sortby
                                 from   dba_hist_sysstat where stat_name = 'physical reads'
                                 union all
                                 select dbid, instance_number, con_id, snap_id, stat_name, 0 pio, value cpu, value sortby
                                 from   dba_hist_sysstat where stat_name = 'CPU used by this session')
                         group by dbid, instance_number, con_id, snap_id))
         where  rn <= 5)        x,
        dba_hist_snapshot       s
where   s.dbid = x.dbid
and     s.instance_number = x.instance_number
and     s.con_id = x.con_id
and     s.snap_id = x.snap_id
order by x.rn;
spool off
