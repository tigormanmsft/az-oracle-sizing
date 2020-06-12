## Sizing Azure resources based on an Oracle AWR report

This package consists of a PDF (i.e. "`AWR Sizing Instructions.pdf`") containing a set of instructions for extracting a small set of metrics from an Oracle AWR report into a spreadsheet.  The spreadsheet (i.e. "`AWR Analysis (template) YYYYMMDD.xls`") will then summarize and extrapolate these metrics into estimates used for sizing the on-prem database on Azure virtual machines and storage.

At present, the spreadsheet does not use the estimated recommendations for CPU, RAM, IOPS, and I/O throughput to automatically pull recommended Azure instance types and storage options;  creating recommendations from the calculations is still quite manual, unfortunately.

To obtain the most accurate observed information from an AWR report, please consider using output from the SQL script "`busiest_awr.sql`" to find peak workloads from which to calculate, with a minimum of extrapolation and guesswork.
