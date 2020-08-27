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
REM     TGorman 09jul20 v0.3 corrected bug, VALUE is cumulative not delta. Also,
REM                     added INSTANCE_NUMBER to report and DBID to calculations
REM     TGorman 26aug20 v0.4 added Snap Begin and Snap End times to output
REM ================================================================================
set pages 100 lines 130 verify off echo off feedback 6 timing off
define V_BUCKETS="10"
define V_CPU_FACTOR="1"
define V_PIO_FACTOR="10"
col instance_number format 990 heading "Inst"
col snap_id format 9999999990 heading "Snapshot ID"
col pio heading "Physical|Reads|(PIO)"
col cpu heading "CPU used by|this session|(CPU)"
col begin_tm format a20 heading "Snap Begin"
col end_tm format a20 heading "Snap End"
spool busiest_awr
select  x.instance_number,
        x.snap_id,
        to_char(s.begin_interval_time, 'DD-MON-YYYY HH24:MI:SS') begin_tm,
        to_char(s.end_interval_time, 'DD-MON-YYYY HH24:MI:SS') end_tm,
        x.pio,
        x.cpu
from    (select instance_number, snap_id, pio, cpu, row_number() over (partition by instance_number order by sortby desc) rn
         from   (select instance_number, snap_id,
                        sum(pio) pio, sum(cpu) cpu, sum(sortby) sortby
                 from   (select instance_number, snap_id, pio, cpu, sortby
                         from   (select instance_number, snap_id, value pio, 0 cpu, (value*(&&V_PIO_FACTOR)) sortby,
                                        ntile(&&V_BUCKETS) over (partition by instance_number order by value) bucket
                                 from   (select instance_number, snap_id,
                                                nvl(decode(greatest(value, nvl(lag(value) over (partition by instance_number order by snap_id),0)),
                                                           value, value - lag(value) over (partition by instance_number order by snap_id),
                                                           value), 0) value
                                         from   dba_hist_sysstat
                                         where  stat_name = 'physical reads'
                                         and    dbid = (select dbid from v$database))
                                 union all
                                 select instance_number, snap_id, 0 pio, value cpu, (value*(&&V_CPU_FACTOR)) sortby,
                                        ntile(&&V_BUCKETS) over (partition by instance_number order by value) bucket
                                 from   (select instance_number, snap_id,
                                                nvl(decode(greatest(value, nvl(lag(value) over (partition by instance_number order by snap_id),0)),
                                                           value, value - lag(value) over (partition by instance_number order by snap_id),
                                                           value), 0) value
                                         from   dba_hist_sysstat
                                         where  stat_name = 'CPU used by this session'
                                         and    dbid = (select dbid from v$database)))
                         where  bucket = &&V_BUCKETS)
                 group by instance_number, snap_id))    x,
        dba_hist_snapshot                               s
where   s.snap_id = x.snap_id
and     s.instance_number = x.instance_number
and     rn <= 5
order by rn;
spool off
