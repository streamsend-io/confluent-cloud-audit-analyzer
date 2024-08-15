#!/bin/ksh
##!/bin/bash
#
# this script locates the latest downloaded file that contains Confluent Cloud Audit Log entries, it loads the data into sqlite and it runs queries to analyze the audit data
#

export SQLITE=./bin/sqlite3
DT=`date +"%Y%m%d"`
DTS=`date +"%Y%m%d%H%M%S"`
TABLE=cc_audit_events
LATEST_AUDIT_DATA_DOWNLOAD=unset
WORKDIR=./work
DATADIR=./data
REPORTDIR=./reports
REPORT=${REPORTDIR}/analyze_audit_logs_${DTS}.txt

mkdir ${DATADIR} ${WORKDIR} ${REPORTDIR} 2>/dev/null
export SQLITE_DATAFILE=${DATADIR}/cc_audit_logs.dbf


recreateDatabaseTable()
{
  W=${WORKDIR}/recreateDatabaseTable.out
  echo "recreateDatabaseTable (I) drop/create sqlite table ${TABLE}"
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
  DROP TABLE IF EXISTS ${TABLE};
  CREATE TABLE ${TABLE} (
     ts                 timestamp
   , method                string
   , id                    string
   , principal             string
   , authidentifier        string
   , principalresourceid   string
   , connectionid          string
   , status                string
   , granted               string
   , operation             string
   , resourceType          string
   , resourceName          string
   , patternType           string
   );
EOF

}

insertCCAuditEvents()
{
  W=${WORKDIR}/insertCCAuditEvents.out
  echo
  echo "insertCCAuditEvents (I) Processing Confluent Cloud Audit Events:"
  cat <<EOF >${REPORT}
  Run at : ${DTS}
  ---------------------------------------------
  Loading Audit events for kafka.Authentication
                             mds.Authorize

 Ignoring Audit events for other methods

EOF
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
  echo "(I):   reading    ${LINE_COUNT} CC audit logs from $LATEST_AUDIT_DATA_DOWNLOAD to populate ${WORKDIR}/${TABLE}.csv"
  sleep 2
  cat $LATEST_AUDIT_DATA_DOWNLOAD |grep -v 'Headers: ' | grep 'kafka.Authentication\|mds.Authorize' |
     jq -r ' [
      .time 
     ,.data.methodName 
     ,.id 
     ,.data.authenticationInfo.principal
     ,.data.authenticationInfo.metadata.identifier 
     ,.data.authenticationInfo.principalResourceId 
     ,.data.requestMetadata.connectionid 
     ,.data.result.status
     ,.data.authorizationInfo.granted
     ,.data.authorizationInfo.operation
     ,.data.authorizationInfo.resourceType
     ,.data.authorizationInfo.resourceName
     ,.data.authorizationInfo.patternType
     ] |@csv' > ${WORKDIR}/${TABLE}_1.csv 2>${WORKDIR}/${TABLE}_ERRORS.txt

  LINE_COUNT=`cat ${WORKDIR}/${TABLE}_1.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE}_1.csv for kafka.Authentication & mds.Authorize"

 cat $LATEST_AUDIT_DATA_DOWNLOAD |grep -v 'Headers: ' | grep -v 'kafka.Authentication' | grep -v 'mds.Authorize' |
     jq -r ' [
      .time
     ,.data.methodName
     ,.id
     ] |@csv' >> ${WORKDIR}/${TABLE}_2.csv 2>>${WORKDIR}/${TABLE}_ERRORS.txt

  # load the CSV into sqlite
  LINE_COUNT=`cat ${WORKDIR}/${TABLE}_2.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE}_2.csv for other event types"
  
  if [ -f "${WORKDIR}/${TABLE}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE}_ERRORS.txt|wc -l|sed "s/ //"`
    echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE}_ERRORS.txt"
  fi
  sleep 2
  cat ${WORKDIR}/${TABLE}_1.csv ${WORKDIR}/${TABLE}_2.csv > ${WORKDIR}/${TABLE}.csv 2>/dev/null
  LINE_COUNT=`cat ${WORKDIR}/${TABLE}.csv|wc -l|sed "s/ //"`
  echo "(I):   all events ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE}.csv for all event types"

  #${SQLITE} ${SQLITE_DATAFILE} 2>(grep -v 'expected 13 columns but found 3 - filling the rest with NULL' >&2)  <<EOF
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
.import ${WORKDIR}/${TABLE}.csv cc_audit_events
EOF
rm -f ${WORKDIR}/${TABLE}_1.csv ${WORKDIR}/${TABLE}_1.csv ${WORKDIR}/${TABLE}.csv
echo
echo "(I):   ${WORKDIR}/${TABLE}.csv successfully loaded into sqlite"
sleep 2
 
}




analyzeAllEvents()
{
  W=${WORKDIR}/analyzeAllEvents.out
cat <<EOF >> ${REPORT}

#
# Confluent Cloud Audit Log Contents: start/end date for Audit Logs, the count of audit log entries by method by principal (username) 
#
EOF

${SQLITE} ${SQLITE_DATAFILE} >> ${REPORT} <<EOF 
.mode column
.width 50
      SELECT min(ts) as audit_start_time, max(ts) as audit_end_time FROM ${TABLE};
EOF

${SQLITE} ${SQLITE_DATAFILE} >> ${REPORT} <<EOF 
.mode column
.width 50
      SELECT method, count(*) number_of_audit_entries FROM ${TABLE} GROUP BY method ORDER BY 2 desc;
EOF

${SQLITE} ${SQLITE_DATAFILE} >> ${REPORT} <<EOF 
.mode column
.width 50
      SELECT principal, count(*) audit_entries_per_username FROM ${TABLE} GROUP BY principal ORDER BY 2 desc;
EOF

}

analyzeKafkaAuthorizationEvents()
{
  W=${WORKDIR}/analyzeKafkaAuthorizationEvents.out
cat <<EOF >> ${REPORT}

#
# Analyze kafka.Authentication events. Find the busiest day (most audit events) and show the number of auth  events per principal per hour for 24 hours
#
EOF

${SQLITE} ${SQLITE_DATAFILE}  >>${REPORT} <<EOF 
.mode column
.width 200
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs ,  principal, status FROM ${TABLE} where method = 'kafka.Authentication' ORDER BY principal, ts)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT principal, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events from Q1,Q2b WHERE substr(ts_msecs,1,10)=best_dd group by principal, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
          ,Q3a as (SELECT distinct principal principals from Q3)
          ,Q4_00 as (SELECT principal, events,hh from Q3 where hh='00' )
          ,Q4_01 as (SELECT principal, events,hh from Q3 where hh='01' )
          ,Q4_02 as (SELECT principal, events,hh from Q3 where hh='02' )
          ,Q4_03 as (SELECT principal, events,hh from Q3 where hh='03' )
          ,Q4_04 as (SELECT principal, events,hh from Q3 where hh='04' )
          ,Q4_05 as (SELECT principal, events,hh from Q3 where hh='05' )
          ,Q4_06 as (SELECT principal, events,hh from Q3 where hh='06' )
          ,Q4_07 as (SELECT principal, events,hh from Q3 where hh='07' )
          ,Q4_08 as (SELECT principal, events,hh from Q3 where hh='08' )
          ,Q4_09 as (SELECT principal, events,hh from Q3 where hh='09' )
          ,Q4_10 as (SELECT principal, events,hh from Q3 where hh='10' )
          ,Q4_11 as (SELECT principal, events,hh from Q3 where hh='11' )
          ,Q4_12 as (SELECT principal, events,hh from Q3 where hh='12' )
          ,Q4_13 as (SELECT principal, events,hh from Q3 where hh='13' )
          ,Q4_14 as (SELECT principal, events,hh from Q3 where hh='14' )
          ,Q4_15 as (SELECT principal, events,hh from Q3 where hh='15' )
          ,Q4_16 as (SELECT principal, events,hh from Q3 where hh='16' )
          ,Q4_17 as (SELECT principal, events,hh from Q3 where hh='17' )
          ,Q4_18 as (SELECT principal, events,hh from Q3 where hh='18' )
          ,Q4_19 as (SELECT principal, events,hh from Q3 where hh='19' )
          ,Q4_20 as (SELECT principal, events,hh from Q3 where hh='20' )
          ,Q4_21 as (SELECT principal, events,hh from Q3 where hh='21' )
          ,Q4_22 as (SELECT principal, events,hh from Q3 where hh='22' )
          ,Q4_23 as (SELECT principal, events,hh from Q3 where hh='23' )
          ,Q5a   as (SELECT '                                                        Kafka Authentication Events For one Day (the day with the most Audit Data)' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '       Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5c   as (SELECT 'Principal        ' line, 2 seq)
          ,Q5d   as (SELECT '   Logins________       ____________________________________________________________________________________________________________________________________________' line, 3 seq)
          ,Q5e   as (SELECT substr(Q3a.principals||'                  ',1,20)
                     ||' '||substr('    '||IfNull(Q4_00.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_01.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_02.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_03.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_04.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_05.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_06.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_07.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_08.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_09.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_10.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_11.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_12.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_13.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_14.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_15.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_16.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_17.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_18.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_19.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_20.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_21.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_22.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_23.events,'-'),-5,5) 
                     line, 4 seq
                 FROM Q3a
                   LEFT OUTER JOIN Q4_00 ON Q4_00.principal = principals
                   LEFT OUTER JOIN Q4_01 ON Q4_01.principal = principals
                   LEFT OUTER JOIN Q4_02 ON Q4_02.principal = principals
                   LEFT OUTER JOIN Q4_03 ON Q4_03.principal = principals
                   LEFT OUTER JOIN Q4_04 ON Q4_04.principal = principals
                   LEFT OUTER JOIN Q4_05 ON Q4_05.principal = principals
                   LEFT OUTER JOIN Q4_06 ON Q4_06.principal = principals
                   LEFT OUTER JOIN Q4_07 ON Q4_07.principal = principals
                   LEFT OUTER JOIN Q4_08 ON Q4_08.principal = principals
                   LEFT OUTER JOIN Q4_09 ON Q4_09.principal = principals
                   LEFT OUTER JOIN Q4_10 ON Q4_10.principal = principals
                   LEFT OUTER JOIN Q4_11 ON Q4_11.principal = principals
                   LEFT OUTER JOIN Q4_12 ON Q4_12.principal = principals
                   LEFT OUTER JOIN Q4_13 ON Q4_13.principal = principals
                   LEFT OUTER JOIN Q4_14 ON Q4_14.principal = principals
                   LEFT OUTER JOIN Q4_15 ON Q4_15.principal = principals
                   LEFT OUTER JOIN Q4_16 ON Q4_16.principal = principals
                   LEFT OUTER JOIN Q4_17 ON Q4_17.principal = principals
                   LEFT OUTER JOIN Q4_18 ON Q4_18.principal = principals
                   LEFT OUTER JOIN Q4_19 ON Q4_19.principal = principals
                   LEFT OUTER JOIN Q4_20 ON Q4_20.principal = principals
                   LEFT OUTER JOIN Q4_21 ON Q4_21.principal = principals
                   LEFT OUTER JOIN Q4_22 ON Q4_22.principal = principals
                   LEFT OUTER JOIN Q4_23 ON Q4_23.principal = principals
                    )
          , Q5  as (       SELECT seq, line from q5a
                     UNION SELECT seq, line from q5b
                     UNION SELECT seq, line from q5c
                     UNION SELECT seq, line from q5d
                     UNION SELECT seq, line from q5e
                   )
          SELECT line from Q5 order by seq
EOF
}



analyzeMdsAuthorizeEvents()
{
  W=${WORKDIR}/analyzeMdsAuthorizeEvents.out
cat <<EOF >> ${REPORT}

#
# Analyze mds.Authorize events. Find the busiest day and show the number of MDS Authorization Requests per principle per Operation 
#
EOF

${SQLITE} ${SQLITE_DATAFILE} >> ${REPORT} <<EOF 
.mode column
.width 200
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs, replace(principal,'User:','')||'-'||Operation principal,status FROM ${TABLE} where method = 'mds.Authorize' ORDER BY principal, ts)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT principal, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events from Q1,Q2b WHERE substr(ts_msecs,1,10)=best_dd group by principal, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
          ,Q3a as (SELECT distinct principal principals from Q3)
          ,Q4_00 as (SELECT principal, events,hh from Q3 where hh='00' )
          ,Q4_01 as (SELECT principal, events,hh from Q3 where hh='01' )
          ,Q4_02 as (SELECT principal, events,hh from Q3 where hh='02' )
          ,Q4_03 as (SELECT principal, events,hh from Q3 where hh='03' )
          ,Q4_04 as (SELECT principal, events,hh from Q3 where hh='04' )
          ,Q4_05 as (SELECT principal, events,hh from Q3 where hh='05' )
          ,Q4_06 as (SELECT principal, events,hh from Q3 where hh='06' )
          ,Q4_07 as (SELECT principal, events,hh from Q3 where hh='07' )
          ,Q4_08 as (SELECT principal, events,hh from Q3 where hh='08' )
          ,Q4_09 as (SELECT principal, events,hh from Q3 where hh='09' )
          ,Q4_10 as (SELECT principal, events,hh from Q3 where hh='10' )
          ,Q4_11 as (SELECT principal, events,hh from Q3 where hh='11' )
          ,Q4_12 as (SELECT principal, events,hh from Q3 where hh='12' )
          ,Q4_13 as (SELECT principal, events,hh from Q3 where hh='13' )
          ,Q4_14 as (SELECT principal, events,hh from Q3 where hh='14' )
          ,Q4_15 as (SELECT principal, events,hh from Q3 where hh='15' )
          ,Q4_16 as (SELECT principal, events,hh from Q3 where hh='16' )
          ,Q4_17 as (SELECT principal, events,hh from Q3 where hh='17' )
          ,Q4_18 as (SELECT principal, events,hh from Q3 where hh='18' )
          ,Q4_19 as (SELECT principal, events,hh from Q3 where hh='19' )
          ,Q4_20 as (SELECT principal, events,hh from Q3 where hh='20' )
          ,Q4_21 as (SELECT principal, events,hh from Q3 where hh='21' )
          ,Q4_22 as (SELECT principal, events,hh from Q3 where hh='22' )
          ,Q4_23 as (SELECT principal, events,hh from Q3 where hh='23' )
          ,Q5a   as (SELECT '                                                                   MDS Authorize Events For one Day (The day with the most Audit data)' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5c   as (SELECT 'Principal                  ' line, 2 seq)
          ,Q5d   as (SELECT '   Logins________                 ____________________________________________________________________________________________________________________________________________' line, 3 seq)
          ,Q5e   as (SELECT substr(Q3a.principals||'                            ',1,30)
                     ||' '||substr('    '||IfNull(Q4_00.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_01.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_02.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_03.events,'-'),-5,5)
                     ||' '||substr('    '||IfNull(Q4_04.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_05.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_06.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_07.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_08.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_09.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_10.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_11.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_12.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_13.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_14.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_15.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_16.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_17.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_18.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_19.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_20.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_21.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_22.events,'-'),-5,5) 
                     ||' '||substr('    '||IfNull(Q4_23.events,'-'),-5,5) 
                     line, 4 seq
                 FROM Q3a
                   LEFT OUTER JOIN Q4_00 ON Q4_00.principal = principals
                   LEFT OUTER JOIN Q4_01 ON Q4_01.principal = principals
                   LEFT OUTER JOIN Q4_02 ON Q4_02.principal = principals
                   LEFT OUTER JOIN Q4_03 ON Q4_03.principal = principals
                   LEFT OUTER JOIN Q4_04 ON Q4_04.principal = principals
                   LEFT OUTER JOIN Q4_05 ON Q4_05.principal = principals
                   LEFT OUTER JOIN Q4_06 ON Q4_06.principal = principals
                   LEFT OUTER JOIN Q4_07 ON Q4_07.principal = principals
                   LEFT OUTER JOIN Q4_08 ON Q4_08.principal = principals
                   LEFT OUTER JOIN Q4_09 ON Q4_09.principal = principals
                   LEFT OUTER JOIN Q4_10 ON Q4_10.principal = principals
                   LEFT OUTER JOIN Q4_11 ON Q4_11.principal = principals
                   LEFT OUTER JOIN Q4_12 ON Q4_12.principal = principals
                   LEFT OUTER JOIN Q4_13 ON Q4_13.principal = principals
                   LEFT OUTER JOIN Q4_14 ON Q4_14.principal = principals
                   LEFT OUTER JOIN Q4_15 ON Q4_15.principal = principals
                   LEFT OUTER JOIN Q4_16 ON Q4_16.principal = principals
                   LEFT OUTER JOIN Q4_17 ON Q4_17.principal = principals
                   LEFT OUTER JOIN Q4_18 ON Q4_18.principal = principals
                   LEFT OUTER JOIN Q4_19 ON Q4_19.principal = principals
                   LEFT OUTER JOIN Q4_20 ON Q4_20.principal = principals
                   LEFT OUTER JOIN Q4_21 ON Q4_21.principal = principals
                   LEFT OUTER JOIN Q4_22 ON Q4_22.principal = principals
                   LEFT OUTER JOIN Q4_23 ON Q4_23.principal = principals
                    )
          , Q5  as (       SELECT seq, line from q5a
                     UNION SELECT seq, line from q5b
                     UNION SELECT seq, line from q5c
                     UNION SELECT seq, line from q5d
                     UNION SELECT seq, line from q5e
                   )
          SELECT line from Q5 order by seq
EOF
}

checkDownloadedAuditLogs()
{
  W=${WORKDIR}/checkDownloadedAuditLogs.out
  LATEST_AUDIT_DATA_DOWNLOAD=`ls -1 ${DATADIR}/*audit_logs_202*|tail -1`
}

#
# starts here
#
checkDownloadedAuditLogs
recreateDatabaseTable
insertCCAuditEvents
analyzeAllEvents
analyzeKafkaAuthorizationEvents
analyzeMdsAuthorizeEvents
echo
echo "Results written to ${REPORT}"
cat ${REPORT}

