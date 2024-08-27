#!/usr/bin/env bash
#
#note that bash is required below for the "${!SELECT_CLAUSE}" substitutions
# this script locates the latest downloaded file that contains Confluent Cloud Audit Log entries, it loads the data into sqlite and it runs queries to analyze the audit data
#

export SQLITE=./bin/sqlite3
DT=`date +"%Y%m%d"`
DTS=`date +"%Y%m%d%H%M%S"`
TABLE=cc_audit_events
TABLE1=AUTH_EVENTS
TABLE1_SELECT_CLAUSE="REPLACE(principal,'User:','')||'-'||Operation selector, status"
TABLE1_WHERE_CLAUSE="AND method = 'mds.Authorize'"
TABLE1_TITLE='                                                                   MDS Authorize Events '

TABLE2=SIGNIN_FAIL
TABLE2_SELECT_CLAUSE="principal||' ('||errorcode||')' selector"
TABLE2_WHERE_CLAUSE="AND method = 'SignIn' AND result = 'FAILURE'"
TABLE2_TITLE='                                                                   Sign-In Failure Events '

TABLE3=SIGNIN_SUCCESS
TABLE3_SELECT_CLAUSE="principal selector"
TABLE3_WHERE_CLAUSE="AND method = 'SignIn' AND result = 'SUCCESS'"
TABLE3_TITLE='                                                                   Sign-In Success Events '

TABLE4=OTHER_EVENTS
TABLE4_SELECT_CLAUSE="method selector"
TABLE4_WHERE_CLAUSE="AND 1=1"
TABLE4_TITLE='                                                                   All CC Audit Events '

LATEST_AUDIT_DATA_DOWNLOAD=unset
WORKDIR=./work
DATADIR=./data
REPORTDIR=./reports


mkdir -p ${REPORTDIR}/${TABLE1} ${REPORTDIR}/${TABLE2} ${REPORTDIR}/${TABLE3} ${REPORTDIR}/${TABLE4}
mkdir ${DATADIR} ${WORKDIR} ${REPORTDIR} 2>/dev/null
export SQLITE_DATAFILE=${DATADIR}/cc_audit_logs_${DTS}.dbf


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
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
  #echo "(I):   reading    ${LINE_COUNT} CC audit logs from $LATEST_AUDIT_DATA_DOWNLOAD to populate ${WORKDIR}/${TABLE1}.csv"
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
    #echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE1}_ERRORS.txt"
  fi
  sleep 2

  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
DELETE from ${TABLE1};
.import ${WORKDIR}/${TABLE1}.csv ${TABLE1}
EOF
rm -f ${W} ${WORKDIR}/${TABLE1}.csv

}



insertTable2SignInFail()
{
  W=${WORKDIR}/${TABLE2}.out
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
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
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE2}.csv for SignIn Fail"

 if [ -f "${WORKDIR}/${TABLE2}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE2}_ERRORS.txt|wc -l|sed "s/ //"`
    #echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE2}_ERRORS.txt"
  fi
  sleep 2

  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
DELETE from ${TABLE2};
.import ${WORKDIR}/${TABLE2}.csv ${TABLE2}
EOF
rm -f ${W} ${WORKDIR}/${TABLE2}.csv
}


insertTable3SignInSuccess()
{
  W=${WORKDIR}/${TABLE3}.out
  LINE_COUNT=`cat ${LATEST_AUDIT_DATA_DOWNLOAD}|grep -v "Headers: "|wc -l|sed "s/ //"`
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
     ] |@csv' >> ${WORKDIR}/${TABLE3}.csv 2>${WORKDIR}/${TABLE3}_ERRORS.txt

  LINE_COUNT=`cat ${WORKDIR}/${TABLE3}.csv|wc -l|sed "s/ //"`
  echo "(I):   populated  ${LINE_COUNT} CC audit logs into ${WORKDIR}/${TABLE3}.csv for SignIn Success"

 if [ -f "${WORKDIR}/${TABLE3}_ERRORS.txt" ]
  then
    LINE_COUNT=`cat ${WORKDIR}/${TABLE3}_ERRORS.txt|wc -l|sed "s/ //"`
    #echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE3}_ERRORS.txt"
  fi
  sleep 2

  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
DELETE from ${TABLE3};
.import ${WORKDIR}/${TABLE3}.csv ${TABLE3}
EOF
rm -f ${W} ${WORKDIR}/${TABLE3}.csv
}




insertTable4AllOtherEvents()
{
  W=${WORKDIR}/${TABLES3}.out
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
    #echo "(I):   populated  ${LINE_COUNT} ERROR lines into ${WORKDIR}/${TABLE4}_ERRORS.txt"
  fi
  sleep 2

  ${SQLITE} ${SQLITE_DATAFILE} <<EOF
.mode csv
DELETE from ${TABLE4};
.import ${WORKDIR}/${TABLE4}.csv ${TABLE4}
EOF
rm -f ${W} ${WORKDIR}/${TABLE4}.csv
}




getDateSpan()
{
  W=${WORKDIR}/getDateSpan.out

${SQLITE} ${SQLITE_DATAFILE} >${W} <<EOF 
.headers off
.mode column
.width 50
      SELECT 'export START_DATE='||min(strftime('%Y-%m-%d',ts)) from ${TABLE4};
      SELECT 'export NUMBER_OF_DAYS='||CAST(0+(round(max(strftime('%J',ts)))-round(min(strftime('%J',ts)))) as integer) from ${TABLE4};
EOF
cat ${W} | grep export  > ${W}.1
. ./${W}.1

}




runCCAuditQuery()
{

  PROCESS_DATE=${1}
  TABLE_NAME=${2}
  SELECT_CLAUSE=${3}
  WHERE_CLAUSE=${4}
  TITLE=${5}
  # ${!TABLE_NAME} : bash expansion the value in the variable that is in the variable in TABLE_NAME
  
  W=${REPORTDIR}/${!TABLE_NAME}/${PROCESS_DATE}.txt

${SQLITE} ${SQLITE_DATAFILE} > ${W}.PROCESSING <<EOF 
.mode column
.width 174
      WITH Q1 as (SELECT strftime('%Y-%m-%dT%H:%M:%S.%f',ts) as ts_msecs, 
                         ${!SELECT_CLAUSE}
                    FROM ${!TABLE_NAME} 
                   WHERE strftime('%Y-%m-%d',ts) = '${PROCESS_DATE}'
                         ${!WHERE_CLAUSE}
                ORDER BY 2,1)
          ,Q2a as (SELECT substr(ts_msecs,1,10) ts_dd, count(*) events from Q1 group by substr(ts_msecs,1,10) ORDER BY 2 DESC)
          ,Q2b as (SELECT ts_dd best_dd from Q2a limit 1)
          ,Q3 as (SELECT selector, substr(ts_msecs,1,10) ts_dd, substr(ts_msecs,12,2) hh,  count(*) events 
                    FROM Q1,Q2b 
                   WHERE substr(ts_msecs,1,10)=best_dd 
                GROUP BY selector, substr(ts_msecs,1,10),substr(ts_msecs,12,2))
          ,Q3a as (SELECT distinct selector selectors from Q3)
          ,Q4_00 as (SELECT selector, events,hh from Q3 where hh='00' )
          ,Q4_01 as (SELECT selector, events,hh from Q3 where hh='01' )
          ,Q4_02 as (SELECT selector, events,hh from Q3 where hh='02' )
          ,Q4_03 as (SELECT selector, events,hh from Q3 where hh='03' )
          ,Q4_04 as (SELECT selector, events,hh from Q3 where hh='04' )
          ,Q4_05 as (SELECT selector, events,hh from Q3 where hh='05' )
          ,Q4_06 as (SELECT selector, events,hh from Q3 where hh='06' )
          ,Q4_07 as (SELECT selector, events,hh from Q3 where hh='07' )
          ,Q4_08 as (SELECT selector, events,hh from Q3 where hh='08' )
          ,Q4_09 as (SELECT selector, events,hh from Q3 where hh='09' )
          ,Q4_10 as (SELECT selector, events,hh from Q3 where hh='10' )
          ,Q4_11 as (SELECT selector, events,hh from Q3 where hh='11' )
          ,Q4_12 as (SELECT selector, events,hh from Q3 where hh='12' )
          ,Q4_13 as (SELECT selector, events,hh from Q3 where hh='13' )
          ,Q4_14 as (SELECT selector, events,hh from Q3 where hh='14' )
          ,Q4_15 as (SELECT selector, events,hh from Q3 where hh='15' )
          ,Q4_16 as (SELECT selector, events,hh from Q3 where hh='16' )
          ,Q4_17 as (SELECT selector, events,hh from Q3 where hh='17' )
          ,Q4_18 as (SELECT selector, events,hh from Q3 where hh='18' )
          ,Q4_19 as (SELECT selector, events,hh from Q3 where hh='19' )
          ,Q4_20 as (SELECT selector, events,hh from Q3 where hh='20' )
          ,Q4_21 as (SELECT selector, events,hh from Q3 where hh='21' )
          ,Q4_22 as (SELECT selector, events,hh from Q3 where hh='22' )
          ,Q4_23 as (SELECT selector, events,hh from Q3 where hh='23' )
          ,Q5a   as (SELECT '${!TITLE}' line, 0 seq)
          ,Q5b   as (SELECT best_dd || '                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23' line, 1 seq from q2b )
          ,Q5d   as (SELECT '___________________________       ____________________________________________________________________________________________________________________________________________' line, 3 seq)
          ,Q5e   as (SELECT substr(Q3a.selectors||'                            ',1,30)
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
                   LEFT OUTER JOIN Q4_00 ON Q4_00.selector = selectors
                   LEFT OUTER JOIN Q4_01 ON Q4_01.selector = selectors
                   LEFT OUTER JOIN Q4_02 ON Q4_02.selector = selectors
                   LEFT OUTER JOIN Q4_03 ON Q4_03.selector = selectors
                   LEFT OUTER JOIN Q4_04 ON Q4_04.selector = selectors
                   LEFT OUTER JOIN Q4_05 ON Q4_05.selector = selectors
                   LEFT OUTER JOIN Q4_06 ON Q4_06.selector = selectors
                   LEFT OUTER JOIN Q4_07 ON Q4_07.selector = selectors
                   LEFT OUTER JOIN Q4_08 ON Q4_08.selector = selectors
                   LEFT OUTER JOIN Q4_09 ON Q4_09.selector = selectors
                   LEFT OUTER JOIN Q4_10 ON Q4_10.selector = selectors
                   LEFT OUTER JOIN Q4_11 ON Q4_11.selector = selectors
                   LEFT OUTER JOIN Q4_12 ON Q4_12.selector = selectors
                   LEFT OUTER JOIN Q4_13 ON Q4_13.selector = selectors
                   LEFT OUTER JOIN Q4_14 ON Q4_14.selector = selectors
                   LEFT OUTER JOIN Q4_15 ON Q4_15.selector = selectors
                   LEFT OUTER JOIN Q4_16 ON Q4_16.selector = selectors
                   LEFT OUTER JOIN Q4_17 ON Q4_17.selector = selectors
                   LEFT OUTER JOIN Q4_18 ON Q4_18.selector = selectors
                   LEFT OUTER JOIN Q4_19 ON Q4_19.selector = selectors
                   LEFT OUTER JOIN Q4_20 ON Q4_20.selector = selectors
                   LEFT OUTER JOIN Q4_21 ON Q4_21.selector = selectors
                   LEFT OUTER JOIN Q4_22 ON Q4_22.selector = selectors
                   LEFT OUTER JOIN Q4_23 ON Q4_23.selector = selectors
                    )
          , Q5  as (       SELECT seq, line from q5a
                     UNION SELECT seq, line from q5b
                     UNION SELECT seq, line from q5d
                     UNION SELECT seq, line from q5e
                   )
          SELECT line from Q5 order by seq
EOF

# Append this to the compiled report for a single day

# CC audit data ages by hour; so if we have saved a larger report for this report, for this date, previously, then dont overwrite the older (more complete) report
if [ -f ${W} ]
then
   SIZE=`ls -l ${W}|awk '{print $5}'|sed "s/ //g"`
   if [ -f  ${W}.PROCESSING ]
   then
     SIZE_PROCESSING=`ls -l ${W}.PROCESSING|awk '{print $5}'|sed "s/ //g"`
     if [  "${SIZE_PROCESSING}" -lt "${SIZE}" ]
     then
       echo "(W) discarding ${W} (size ${SIZE_PROCESSING} bytes) becuase an earlier, more complete report exists (size ${SIZE} bytes)"
     else
       cp ${W}.PROCESSING ${W}
       cat ${W}.PROCESSING   > ${REPORTDIR}/${PROCESS_DATE}.txt
     fi
   fi
else
  cp ${W}.PROCESSING ${W}
  cat ${W}.PROCESSING  >> ${REPORTDIR}/${PROCESS_DATE}.txt
fi
rm -f ${W}.PROCESSING
}



checkDownloadedAuditLogs()
{
  W=${WORKDIR}/checkDownloadedAuditLogs.out
  LATEST_AUDIT_DATA_DOWNLOAD=`ls -1 ${DATADIR}/*audit_logs_202*|tail -1`
  SUMMARY_LINE="${LATEST_AUDIT_DATA_DOWNLOAD}: "
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
TOTAL_EVENT_COUNT=`${SQLITE} ${SQLITE_DATAFILE} "SELECT count(*) FROM ${TABLE4}"`
for (( i=0; i <= ${NUMBER_OF_DAYS}; ++i ))
do
    # call each query with a Date parameter to process 24 hours of data at a time
    PROCESS_DATE=`${SQLITE} ${SQLITE_DATAFILE} "SELECT date(strftime('%Y-%m-%d','${START_DATE}'),'+${i} day')"`
    EVENT_COUNT=`${SQLITE} ${SQLITE_DATAFILE} "SELECT count(*) FROM ${TABLE4} WHERE strftime('%Y-%m-%d',ts) = '${PROCESS_DATE}'"`
    echo '' > ${REPORTDIR}/${PROCESS_DATE}.txt
    for (( j=1; j<=4 ; ++j ))
    do
      VAR_TABLE="TABLE${j}"
      VAR_SELECT="TABLE${j}_SELECT_CLAUSE"
      VAR_WHERE="TABLE${j}_WHERE_CLAUSE"
      VAR_TITLE="TABLE${j}_TITLE"
      runCCAuditQuery ${PROCESS_DATE} ${VAR_TABLE} ${VAR_SELECT} ${VAR_WHERE} ${VAR_TITLE}
    done
    SUMMARY_LINE="${SUMMARY_LINE} ${PROCESS_DATE}:(${EVENT_COUNT} events)"
done
echo;echo;echo "Audit Summary for ${TOTAL_EVENT_COUNT} events spanning ${NUMBER_OF_DAYS} days from ${START_DATE}"
echo ${SUMMARY_LINE}
echo ${SUMMARY_LINE} >> reports/summaries.txt
echo;echo "See /reports for daily audit reports"
sleep 2
echo "Report for ${PROCESS_DATE}:"
sleep 1
cat ${REPORTDIR}/${PROCESS_DATE}.txt
rm ${SQLITE_DATAFILE}


echo;echo
