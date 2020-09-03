/*********************************************************************************
 * File:        dbspace.sql
 * Type:        Oracle SQL*Plus script
 * Date:        26-Aug 2020
 * Author:      Microsoft Customer Architecture & Engineering (CAE)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Copyright (c) 2020 by Microsoft. All rights reserved.
 *
 * Description:
 *
 *      Oracle SQL*Plus script to display summary information about the size of an
 *      Oracle database, summarizing datafiles, tempfiles, controlfiles, online
 *      redo log files, and block change tracking files.  Also summarizes backups
 *      of datafiles and archived redo log files.
 *
 *      Output is spooled to the present working directory to a file named
 *      "dbspace_<DB-NAME>.lst", where "DB-NAME" is the database name.
 *
 * Modifications:
 *      TGorman 26-Aug 2020     v1.0 - written
 *      TGorman 03-Sep 2020     v1.1 - added SQL*Plus "set" for formatting
 ********************************************************************************/
set pagesize 100 linesize 130 trimout on trimspool on pause off
col name new_value V_DBNAME noprint
select name from v$database;
spool dbspace_&&V_DBNAME
clear breaks computes
break on report
compute sum of mb on report
col type format a10 heading "File type"
col mb format 999,999,990.00 heading "DB Size (MB)"
select  type, sum(bytes)/1048576 mb
from    (select 'Datafile' type, bytes from dba_data_files
         union all
         select 'Tempfile' type, bytes from dba_temp_files
         union all
         select 'OnlineRedo' type, bytes*members bytes from v$log
         union all
         select 'Ctlfile' type, file_size_blks*block_size bytes from v$controlfile
         union all
         select 'BCTfile' type, nvl(bytes,0) bytes from v$block_change_tracking)
group by type
order by type;

col sort0 noprint
col dbf_mb format 999,999,999,990.00 heading "Source|database|files (MB)"
col day heading "Day"
col backup_type format a4 heading "Bkup|Type"
col incremental_level format 9990 heading "Incr|Lvl"
col read_mb format 999,999,999,990.00 heading "Backup|read|(MB)"
col bkp_mb format 999,999,999,990.00 heading "Database file|backup written|(MB)"
clear breaks computes
break on day on report
compute sum of dbf_mb on report
compute sum of read_mb on report
compute sum of bkp_mb on report
select  to_char(f.completion_time,'YYYYMMDD') sort0,
        to_char(f.completion_time,'DD-MON-YYYY') day,
        s.backup_type,
        s.incremental_level,
        sum(f.datafile_blocks*f.block_size)/1048576 dbf_mb,
        sum(f.blocks_read*f.block_size)/1048576 read_mb,
        sum(f.blocks*f.block_size)/1048576 bkp_mb
from    v$backup_datafile       f,
        v$backup_set            s
where   s.set_stamp = f.set_stamp
and     s.set_count = f.set_count
group by to_char(f.completion_time,'YYYYMMDD'),
         to_char(f.completion_time,'DD-MON-YYYY'),
         s.backup_type,
         s.incremental_level
order by sort0;

clear breaks computes
break on day on report
compute sum of mb on report
col sort0 noprint
col day heading "Day"
col mb format 999,999,990.00 heading "Archived|redo Size (MB)"
select  to_char(next_time,'YYYYMMDD') sort0,
        to_char(next_time,'DD-MON-YYYY') day,
        sum(blocks*block_size)/1048576 mb
from    v$archived_log
group by to_char(next_time,'YYYYMMDD'),
         to_char(next_time,'DD-MON-YYYY')
order by sort0;

clear breaks computes
break on day on report
compute sum of mb on report
col bkp_mb format 999,999,990.00 heading "Archived redo|backup written|(MB)"
select  to_char(next_time,'YYYYMMDD') sort0,
        to_char(next_time,'DD-MON-YYYY') day,
        sum(blocks*block_size)/1048576 bkp_mb
from    v$backup_redolog
group by to_char(next_time,'YYYYMMDD'),
         to_char(next_time,'DD-MON-YYYY')
order by sort0;

clear breaks computes
spool off
