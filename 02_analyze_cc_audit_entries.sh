#!/bin/ksh
#
# this script locates the latest downloaded file that contains Confluent Cloud Audit Log entries, it loads the data into sqlite and it runs queries to analyze the audit data
#

export SQLITE=./bin/sqlite3
DT=`date +"%Y%m%d"`
DTS=`date +"%Y%m%d%H%M%S"`
TABLE=cc_audit_events
TABLE1=AUTH_EVENTS
TABLE2=SIGNIN_FAIL
TABLE3=SIGNIN_SUCCESS
TABLE4=OTHER_EVENTS
LATEST_AUDIT_DATA_DOWNLOAD=unset
WORKDIR=./work
DATADIR=./data
REPORTDIR=./reports


mkdir -p ${REPORTDIR}/${TABLE1} ${REPORTDIR}/${TABLE2} ${REPORTDIR}/${TABLE3} ${REPORTDIR}/${TABLE4}
mkdir ${DATADIR} ${WORKDIR} ${REPORTDIR} 2>/dev/null
export SQLITE_DATAFILE=${DATADIR}/cc_audit_logs.dbf


recreateDatabaseTable()
{
  W=${WORKDIR}/recreateDatabaseTable.out
  echo "recreateDatabaseTable (I) drop/create sqlite table ${TABLE1}"
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
  DROP TABLE IF EXISTS ${TABLE1};
  CREATE TABLE ${TABLE1} (
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


  DROP TABLE IF EXISTS ${TABLE2};
  CREATE TABLE ${TABLE2} (
     ts                 timestamp
   , method                string
   , principal             string
   , result                string
   , clientAddress         string
   , status                string
   , errorCode                string
   , errorMsg                string
   );

  DROP TABLE IF EXISTS ${TABLE3};
  CREATE TABLE ${TABLE3} (
     ts                 timestamp
   , method                string
   , principal             string
   , result                string
   , clientAddress         string
   , status                string
   );

  DROP TABLE IF EXISTS ${TABLE4};
  CREATE TABLE ${TABLE4} (
     ts                 timestamp
   , method                string
   , principal             string
  );
EOF

}

insertTable1AuthEvents()
{
  W=${WORKDIR}/insertAuthEvents.out
  echo
  echo "insertCCAuditEvents (I) Processing Confluent Cloud Audit Events:"
#EOF
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
  echo "(I):   reading    ${LINE_COUNT} CC audit logs from $LATEST_AUDIT_DATA_DOWNLOAD to populate ${WORKDIR}/${TABLE1}.csv"
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
     ] |@csv' > ${WORKDIR}/${TABLE1}.csv 2>${WORKDIR}/${TABLE1}_ERRORS.txt

  LINE_COUNT=`cat ${WORKDIR}/${TABLE1}.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE1}.csv for kafka.Authentication & mds.Authorize"

  if [ -f "${WORKDIR}/${TABLE1}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE1}_ERRORS.txt|wc -l|sed "s/ //"`
    echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE1}_ERRORS.txt"
  fi
  sleep 2

  #${SQLITE} ${SQLITE_DATAFILE} 2>(grep -v 'expected 13 columns but found 3 - filling the rest with NULL' >&2)  <<EOF
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
.import ${WORKDIR}/${TABLE1}.csv ${TABLE1}
EOF
  rm -f ${WORKDIR}/${TABLE1}.csv
  echo "(I):   ${WORKDIR}/${TABLE1}.csv successfully loaded into sqlite"

}



insertTable2SignInFail()
{
  W=${WORKDIR}/${TABLE2}.out
  echo
  echo "insertSignIn(I) Processing Confluent Cloud Audit Events:"
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
  echo "(I):   reading    ${LINE_COUNT} CC audit logs from $LATEST_AUDIT_DATA_DOWNLOAD to populate ${WORKDIR}/${TABLE2}.csv"
  sleep 2

  # load FAILURE signIns, including error message
  cat $LATEST_AUDIT_DATA_DOWNLOAD |grep -v 'Headers: ' | grep 'SignIn' | grep 'FAILURE' |
     jq -r ' [
      .time 
     ,.data.methodName 
     ,.data.authenticationInfo.principal.email
     ,.data.authenticationInfo.result
     ,.data.clientAddress
     ,.data.result.status
     ,.data.result.data.errors[].status
     ,.data.result.data.errors[].detail
     ] |@csv' > ${WORKDIR}/${TABLE2}.csv 2>${WORKDIR}/${TABLE2}_ERRORS.txt

  LINE_COUNT=`cat ${WORKDIR}/${TABLE2}.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE2}.csv for SignIn"

 if [ -f "${WORKDIR}/${TABLE2}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE2}_ERRORS.txt|wc -l|sed "s/ //"`
    echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE2}_ERRORS.txt"
  fi
  sleep 2

  #${SQLITE} ${SQLITE_DATAFILE} 2>(grep -v 'expected 13 columns but found 3 - filling the rest with NULL' >&2)  <<EOF
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
.import ${WORKDIR}/${TABLE2}.csv ${TABLE2}
EOF
#rm -f ${WORKDIR}/${TABLE2}.csv
echo
echo "(I):   ${WORKDIR}/${TABLE2}.csv successfully loaded into sqlite"
}


insertTable3SignInSuccess()
{
  W=${WORKDIR}/${TABLE2}.out
  echo
  echo "insertSignIn(I) Processing Confluent Cloud Audit Events:"
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
  echo "(I):   reading    ${LINE_COUNT} CC audit logs from $LATEST_AUDIT_DATA_DOWNLOAD to populate ${WORKDIR}/${TABLE2}.csv"
  sleep 2

  # load SUCCESS signIns to the same table, nulling error message columns
  cat $LATEST_AUDIT_DATA_DOWNLOAD |grep -v 'Headers: ' | grep 'SignIn' | grep 'SUCCESS' |
     jq -r ' [
      .time 
     ,.data.methodName 
     ,.data.authenticationInfo.principal.email
     ,.data.authenticationInfo.result
     ,.data.clientAddress
     ,.data.result.status
     ,null
     ,null
     ] |@csv' >> ${WORKDIR}/${TABLE2}.csv 2>${WORKDIR}/${TABLE2}_ERRORS.txt

  LINE_COUNT=`cat ${WORKDIR}/${TABLE2}.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE2}.csv for SignIn"

 if [ -f "${WORKDIR}/${TABLE2}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE2}_ERRORS.txt|wc -l|sed "s/ //"`
    echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE2}_ERRORS.txt"
  fi
  sleep 2

  #${SQLITE} ${SQLITE_DATAFILE} 2>(grep -v 'expected 13 columns but found 3 - filling the rest with NULL' >&2)  <<EOF
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
.import ${WORKDIR}/${TABLE2}.csv ${TABLE2}
EOF
#rm -f ${WORKDIR}/${TABLE2}.csv
echo
echo "(I):   ${WORKDIR}/${TABLE2}.csv successfully loaded into sqlite"
}




insertTable4AllOtherEvents()
{
  W=${WORKDIR}/${TABLES3}.out
  echo
  echo "insertAllOtherEvents (I) Processing Confluent Cloud Audit Events:"

 cat $LATEST_AUDIT_DATA_DOWNLOAD |grep -v 'Headers: ' | 
     jq -r ' [
      .time
     ,.data.methodName
     ,.id
     ] |@csv' >> ${WORKDIR}/${TABLE4}.csv 2>>${WORKDIR}/${TABLE4}_ERRORS.txt

  # load the CSV into sqlite
  LINE_COUNT=`cat ${WORKDIR}/${TABLE4}.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE4}.csv for other event types"
  
  if [ -f "${WORKDIR}/${TABLE4}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE4}_ERRORS.txt|wc -l|sed "s/ //"`
    echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE4}_ERRORS.txt"
  fi
  sleep 2

  #${SQLITE} ${SQLITE_DATAFILE} 2>(grep -v 'expected 13 columns but found 3 - filling the rest with NULL' >&2)  <<EOF
  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
.import ${WORKDIR}/${TABLE4}.csv ${TABLE4}
EOF
#rm -f ${WORKDIR}/${TABLE4}.csv
echo
echo "(I):   ${WORKDIR}/${TABLE4}.csv successfully loaded into sqlite"
sleep 2
}




getDateSpan()
{
  W=${WORKDIR}/getDateSpan.out

${SQLITE} ${SQLITE_DATAFILE} >${W} <<EOF 
.headers off
.mode column
.width 50
      SELECT 'export START_DATE='||min(strftime('%Y-%m-%d',ts)) from ${TABLE4};
      SELECT 'export NUMBER_OF_DAYS='||count (distinct strftime('%Y-%m-%d',ts)) from ${TABLE4};
EOF
cat ${W} | grep export  > ${W}.1
. ./${W}.1

}



analyzeTable1MdsAuthorizeEvents()     #1 of 4
{
  # analyzeKafkaAuthorizationEvents uses $TABLE1
  PROCESS_DATE=${1}
  W=${REPORTDIR}/${TABLE1}/${PROCESS_DATE}.txt

${SQLITE} ${SQLITE_DATAFILE} > ${W} <<EOF 
.mode column
.width 174
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs, replace(principal,'User:','')||'-'||Operation principal,status 
                    FROM ${TABLE1} 
                   WHERE 1=1
                     AND strftime('%Y-%m-%d',ts) = '${PROCESS_DATE}'
                     AND  method = 'mds.Authorize' 
                ORDER BY principal, ts)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT principal, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events 
                    FROM Q1,Q2b 
                   WHERE substr(ts_msecs,1,10)=best_dd 
                GROUP BY principal, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
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
          ,Q5a   as (SELECT '                                                                   MDS Authorize Events ' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5c   as (SELECT 'Principal                  ' line, 2 seq)
          ,Q5d   as (SELECT 'Principal__________________       __________________________________________________________________________________________________________________________________' line, 3 seq)
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

# Append this to the compiled report for a single day
cat ${REPORTDIR}/${TABLE1}/${PROCESS_DATE}.txt   >> ${REPORTDIR}/${PROCESS_DATE}.txt
echo >> ${REPORTDIR}/${PROCESS_DATE}.txt;echo >> ${REPORTDIR}/${PROCESS_DATE}.txt

}


analyzeSignInFailEvents()      #2 of 4
{
  # analyzeSignInFailEvents uses $TABLE2
  PROCESS_DATE=${1}
  W=${REPORTDIR}/${TABLE2}/${PROCESS_DATE}.txt
${SQLITE} ${SQLITE_DATAFILE} > ${W}<<EOF
.mode column
.width 174
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs, principal||' ('||errorcode||')' principal 
                    FROM ${TABLE2} 
                   WHERE 1=1
                     AND strftime('%Y-%m-%d',ts) = '${PROCESS_DATE}' 
                     AND method = 'SignIn' 
                     AND result = 'FAILURE' 
                ORDER BY principal||' ('||errorcode||')', ts)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT principal, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events 
                    FROM Q1,Q2b 
                   WHERE substr(ts_msecs,1,10)=best_dd 
                GROUP BY principal, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
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
          ,Q5a   as (SELECT '                                                                   Sign-In Failure Events ' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5c   as (SELECT 'Principal                  ' line, 2 seq)
          ,Q5d   as (SELECT 'Principal__________________       __________________________________________________________________________________________________________________________________' line, 3 seq)
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
          SELECT line from Q5 order by seq;
EOF

# Append this to the compiled report for a single day
cat ${REPORTDIR}/${TABLE2}/${PROCESS_DATE}.txt   >> ${REPORTDIR}/${PROCESS_DATE}.txt
echo >> ${REPORTDIR}/${PROCESS_DATE}.txt;echo >> ${REPORTDIR}/${PROCESS_DATE}.txt
}


analyzeSignInSuccessEvents()      #3 of 4
{

 # analyzeSignInSuccessEvents appends for $TABLE2
  PROCESS_DATE=${1}
  W=${REPORTDIR}/${TABLE3}/${PROCESS_DATE}.txt
${SQLITE} ${SQLITE_DATAFILE} > ${W}<<EOF
.mode column
.width 174
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs, principal principal 
                    FROM ${TABLE2} 
                   WHERE 1=1
                     AND strftime('%Y-%m-%d',ts) = '${PROCESS_DATE}' 
                     AND method = 'SignIn' 
                     AND result = 'SUCCESS' 
                ORDER BY principal||' ('||errorcode||')', ts)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT principal, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events 
                    FROM Q1,Q2b 
                   WHERE substr(ts_msecs,1,10)=best_dd 
                GROUP BY principal, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
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
          ,Q5a   as (SELECT '                                                                   Sign-In Success Events ' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5c   as (SELECT 'Principal                  ' line, 2 seq)
          ,Q5d   as (SELECT 'Principal__________________       __________________________________________________________________________________________________________________________________' line, 3 seq)
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
          SELECT line from Q5 order by seq;
EOF

# Append this to the compiled report for a single day
cat ${REPORTDIR}/${TABLE3}/${PROCESS_DATE}.txt   >> ${REPORTDIR}/${PROCESS_DATE}.txt
echo >> ${REPORTDIR}/${PROCESS_DATE}.txt;echo >> ${REPORTDIR}/${PROCESS_DATE}.txt
}


analyzeAllEvents()      #4 of 4
{
 # analyzeAllEvents appends for $TABLE4
  PROCESS_DATE=${1}
  W=${REPORTDIR}/${TABLE4}/${PROCESS_DATE}.txt
  ${SQLITE} ${SQLITE_DATAFILE} > ${W}<<EOF
.mode column
.width 174
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs, method method 
                    FROM ${TABLE4} 
                   WHERE 1=1
                     AND strftime('%Y-%m-%d',ts) = '${PROCESS_DATE}'
                ORDER BY method, ts)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT method, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events 
                    FROM Q1,Q2b 
                   WHERE 1=1
                     AND substr(ts_msecs,1,10)=best_dd 
                GROUP BY method, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
          ,Q3a as (SELECT distinct method methods from Q3)
          ,Q4_00 as (SELECT method, events,hh from Q3 where hh='00' )
          ,Q4_01 as (SELECT method, events,hh from Q3 where hh='01' )
          ,Q4_02 as (SELECT method, events,hh from Q3 where hh='02' )
          ,Q4_03 as (SELECT method, events,hh from Q3 where hh='03' )
          ,Q4_04 as (SELECT method, events,hh from Q3 where hh='04' )
          ,Q4_05 as (SELECT method, events,hh from Q3 where hh='05' )
          ,Q4_06 as (SELECT method, events,hh from Q3 where hh='06' )
          ,Q4_07 as (SELECT method, events,hh from Q3 where hh='07' )
          ,Q4_08 as (SELECT method, events,hh from Q3 where hh='08' )
          ,Q4_09 as (SELECT method, events,hh from Q3 where hh='09' )
          ,Q4_10 as (SELECT method, events,hh from Q3 where hh='10' )
          ,Q4_11 as (SELECT method, events,hh from Q3 where hh='11' )
          ,Q4_12 as (SELECT method, events,hh from Q3 where hh='12' )
          ,Q4_13 as (SELECT method, events,hh from Q3 where hh='13' )
          ,Q4_14 as (SELECT method, events,hh from Q3 where hh='14' )
          ,Q4_15 as (SELECT method, events,hh from Q3 where hh='15' )
          ,Q4_16 as (SELECT method, events,hh from Q3 where hh='16' )
          ,Q4_17 as (SELECT method, events,hh from Q3 where hh='17' )
          ,Q4_18 as (SELECT method, events,hh from Q3 where hh='18' )
          ,Q4_19 as (SELECT method, events,hh from Q3 where hh='19' )
          ,Q4_20 as (SELECT method, events,hh from Q3 where hh='20' )
          ,Q4_21 as (SELECT method, events,hh from Q3 where hh='21' )
          ,Q4_22 as (SELECT method, events,hh from Q3 where hh='22' )
          ,Q4_23 as (SELECT method, events,hh from Q3 where hh='23' )
          ,Q5a   as (SELECT '                                                                   All CC Audit Events ' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5c   as (SELECT '   Method                  ' line, 2 seq)
          ,Q5d   as (SELECT '   Method__________________       ____________________________________________________________________________________________________________________________________________' line, 3 seq)
          ,Q5e   as (SELECT substr(Q3a.methods||'                            ',1,30)
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
                   LEFT OUTER JOIN Q4_00 ON Q4_00.method = methods
                   LEFT OUTER JOIN Q4_01 ON Q4_01.method = methods
                   LEFT OUTER JOIN Q4_02 ON Q4_02.method = methods
                   LEFT OUTER JOIN Q4_03 ON Q4_03.method = methods
                   LEFT OUTER JOIN Q4_04 ON Q4_04.method = methods
                   LEFT OUTER JOIN Q4_05 ON Q4_05.method = methods
                   LEFT OUTER JOIN Q4_06 ON Q4_06.method = methods
                   LEFT OUTER JOIN Q4_07 ON Q4_07.method = methods
                   LEFT OUTER JOIN Q4_08 ON Q4_08.method = methods
                   LEFT OUTER JOIN Q4_09 ON Q4_09.method = methods
                   LEFT OUTER JOIN Q4_10 ON Q4_10.method = methods
                   LEFT OUTER JOIN Q4_11 ON Q4_11.method = methods
                   LEFT OUTER JOIN Q4_12 ON Q4_12.method = methods
                   LEFT OUTER JOIN Q4_13 ON Q4_13.method = methods
                   LEFT OUTER JOIN Q4_14 ON Q4_14.method = methods
                   LEFT OUTER JOIN Q4_15 ON Q4_15.method = methods
                   LEFT OUTER JOIN Q4_16 ON Q4_16.method = methods
                   LEFT OUTER JOIN Q4_17 ON Q4_17.method = methods
                   LEFT OUTER JOIN Q4_18 ON Q4_18.method = methods
                   LEFT OUTER JOIN Q4_19 ON Q4_19.method = methods
                   LEFT OUTER JOIN Q4_20 ON Q4_20.method = methods
                   LEFT OUTER JOIN Q4_21 ON Q4_21.method = methods
                   LEFT OUTER JOIN Q4_22 ON Q4_22.method = methods
                   LEFT OUTER JOIN Q4_23 ON Q4_23.method = methods
                    )
          , Q5  as (       SELECT seq, line from q5a
                     UNION SELECT seq, line from q5b
                     UNION SELECT seq, line from q5c
                     UNION SELECT seq, line from q5d
                     UNION SELECT seq, line from q5e
                   )
          SELECT line from Q5 order by seq;
EOF

# Append this to the compiled report for a single day
cat ${REPORTDIR}/${TABLE4}/${PROCESS_DATE}.txt   >> ${REPORTDIR}/${PROCESS_DATE}.txt
echo >> ${REPORTDIR}/${PROCESS_DATE}.txt;echo >> ${REPORTDIR}/${PROCESS_DATE}.txt
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
insertTable1AuthEvents
insertTable2SignInFail
insertTable3SignInSuccess
insertTable4AllOtherEvents

getDateSpan
for (( i=0; i <= ${NUMBER_OF_DAYS}; ++i ))
do
    # call each query with a Date parameter to process 24 hours of data at a time
    PROCESS_DATE=`${SQLITE} ${SQLITE_DATAFILE} "SELECT date(strftime('%Y-%m-%d','${START_DATE}'),'+${i} day')"`
    echo processing date $PROCESS_DATE
    echo /dev/null > ${REPORTDIR}/${PROCESS_DATE}.txt
    analyzeTable1MdsAuthorizeEvents ${PROCESS_DATE}
    analyzeSignInFailEvents ${PROCESS_DATE}
    analyzeSignInSuccessEvents ${PROCESS_DATE}
    analyzeAllEvents ${PROCESS_DATE}
done
