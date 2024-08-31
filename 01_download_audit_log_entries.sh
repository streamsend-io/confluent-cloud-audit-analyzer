#!/bin/bash
#
# this script uses the confluent cli to download all of the audit log entries for a Confluent Cloud cluster into a text file
# It checks pre-requisites for the confluent cli before starting the download
# See https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#consume-with-confluent-cli
#
F=confluent-audit-log-events.txt

DT=`date +"%Y%m%d"`
DTS=`date +"%Y%m%d%H%M%S"`

CONSUME_SECONDS=45
WORKDIR=./work
DATADIR=./data
REPORTDIR=./reports
REPORT=${REPORTDIR}/download_audit_logs_${DTS}.txt
mkdir ${DATADIR} ${WORKDIR} ${REPORTDIR} 2>/dev/null


kill_after_cmd() {
    local cmd="$1"
    local delay=$2

    cat <<EOF > /tmp/killAfterCmd.sh
    cmd="${cmd}"
    delay=${delay}
    sleep 5    # needed to enable the consume to start up
    # Get the PID(s) of the process(es) matching the command name
    set -x
    pids=\$(pgrep -f "\$cmd")
    set +x

    if [ -z "\$pids" ]; then
        echo "No process found with command: $cmd"
        exit 1
    fi
    echo "Process(es) with command '$cmd' found: \$pids"
    echo "Waiting $delay seconds before killing..."
    sleep "$delay"
    for pid in \$pids; 
    do
        if kill -9 "\$pid" 2>/dev/null; then
            echo "Process \$pid with command '$cmd' killed after $delay seconds."
        fi
    done
EOF
    nohup sh /tmp/killAfterCmd.sh  > /tmp/killAfterCmd.txt & 
}



checkJqInstalled()
{
  W=${WORKDIR}/checkJqInstalled.out
  rm -f ${W}
  script -q -a ${W} type jq 1>/dev/null 2>&1
  RET=$?
  if [ `cat ${W} | grep "jq: not found" | head -1 | wc -l | sed "s/ //g"` -eq 1 ]
  then
    echo "(I) command line utility jq is required. This is used to parse the JSON response from the Confluent Audit API"
    echo "(I) install it using brew install jq"
    echo; echo "Check and restart ..."
    exit 255
  else
    echo "(I) check jq installed: ok"
  fi
}

checkConfluentCliInstalled()
{
  W=${WORKDIR}/checkConfluentCliInstalled.out
  rm -f ${W}
  script -q -a ${W} confluent --version  1>${W} 2>${W}
  RET=$?
  if [ "$RET" -eq 0 ]
  then
    echo "(I) check confluent cli installed: ok"
    #!#rm -f ${W}
  else
    echo "(I) check confluent cli installed: error"
    cat ${W} 2>/dev/null
    echo; echo "Check and restart ..."
    exit 255
  fi
}


checkConfluentCliLoggedIn()
{
  W=${WORKDIR}/checkConfluentCliLoggedIn.out
  rm -f ${W}
  script -q -a ${W} confluent environment list 1>${W} 2>&1
  RET=$?
  if [ "$RET" -eq 0 ]
  then
    echo "(I) check confluent cli logged in: ok"
    #!#rm -f ${W}
  else
    if [ `cat ${W}|grep "You must be logged in to run this command."|wc -l|sed "s/ //"` -eq 1 ]
    then
      echo "(E) Confluent CLI is installed, but not logged in."
      echo "    Please login using "confluent login" now and re-run"
    else
      echo "(I) check confluent cli is logged in: error:"
      cat ${W} 2>/dev/null
      echo; echo "Check and restart ..."
    fi
    exit 255
  fi
}

ConfluentAuditLogDescribe()
{
  W=${WORKDIR}/ConfluentAuditLogDescribe.out
  rm -f ${W}
  script -q -a ${W} confluent audit-log describe 1>${W} 2>&1
  RET=$?
  if [ "$RET" -eq 0 ]
  then
    AUDIT_CLUSTER=`cat ${WORKDIR}/ConfluentAuditLogDescribe.out | grep Cluster|tail -1|awk -F '|' '{print $3}' | sed "s/ //g"`
    echo "(I) Confluent Audit-Log cluster is ${AUDIT_CLUSTER}"
    export AUDIT_CLUSTER
    AUDIT_ENVIRONMENT=`cat ${WORKDIR}/ConfluentAuditLogDescribe.out | grep Environment|tail -1|awk -F '|' '{print $3}' | sed "s/ //g"`
    echo "(I) Confluent Audit-Log environment is ${AUDIT_ENVIRONMENT}"
    export AUDIT_ENVIRONMENT

    SERVICE_ACCOUNT=`cat ${WORKDIR}/ConfluentAuditLogDescribe.out | grep Service|tail -1|awk -F '|' '{print $3}' | sed "s/ //g"`
    echo "(I) Confluent Audit-Log service account is ${SERVICE_ACCOUNT}"
    export SERVICE_ACCOUNT
    #!#rm -f ${W}
  else
    echo "(E) Confluent Audit Log Describe: error"
    cat ${W} 2>/dev/null
    echo "(E) See https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#access-the-audit-log-user-interface"
    echo; echo "Check and restart ..."
    exit 255
  fi
}


ConfluentAuditCheckApiKey()
{
  W=${WORKDIR}/ConfluentAuditCheckApiKey.out
  rm -f ${W}* 
  script -q -a ${W} confluent environment use ${AUDIT_ENVIRONMENT}     1>${W}.1 2>&1
  script -q -a ${W} confluent kafka cluster use ${AUDIT_CLUSTER}       1>${W}.2 2>&1
  script -q -a ${W} confluent api-key list --resource ${AUDIT_CLUSTER} 1>${W}.3 2>&1
  RET=$?

  # an api-key that was "used" before can be expired, which results in  "Error: no API key selected for resource xx"
  # if this happens, search bash history for a prior use command and retry it automatically
  if [ `cat ${W}.3 | grep "^          | " | tail -1 | wc -l | sed "s/ //g"` -eq 1 ]
  then
    # the "Current" column is blank; so no api key has currently been selected
    echo "(W) No api-key has been selected as the current key for audit cluster ${AUDIT_CLUSTER}. This must be rerun periodically."
    echo "(W) run this cmd to check your bash history. If it returns the cmd, then rerun it, and then rerun this script"
    echo
    echo 'history 1000|grep "confluent api-key use"|grep -v grep|head -1'
  fi
  
  if [ `cat ${W} | grep "None found." | tail -1 | wc -l | sed "s/ //g"` -eq 1 ]
  then
    #!#rm -f ${W}
    echo "(E) No Api Key found for audit cluster ${AUDIT_CLUSTER}:" 
    echo "(E) To create an API key, use confluent api-key create --resource ${AUDIT_CLUSTER} --service-account ${SERVICE_ACCOUNT}"
    echo "(E) API keys for audit log cluster ${AUDIT_CLUSTER} must be created using the predefined service account. To get the identifier for the audit-log cluster, run the Confluent CLI confluent audit-log describe command."

    echo "(E) To save the API key, use confluent api-key store --resource ${AUDIT_CLUSTER}"
    echo "(E) See https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#access-the-audit-log-user-interface"
    echo; echo "Check and restart ..."
    exit 255
  else
    echo "(I) Confluent Audit Log Check Api Key: ok"
  fi
}

ConsumeAuditTopic()
{
  W=${WORKDIR}/ConsumerAuditTopic.out
  echo;echo
  echo "(I) Downloading Confluent Cloud audit log entries into file ${DATADIR}/${ORGANIZATION_NAME}_audit_logs_${DTS}"
  echo "(I) Confluent Cloud Audit Logs contain the last 7 days of entries"
  echo "(I) this download will be automatically killed after ${CONSUME_SECONDS} seconds - (this is not an error)"
  echo "(I) The audit log data is in ${DATADIR}/${ORGANIZATION_NAME}_audit_logs_${DTS}"
  echo;echo

  kill_after_cmd "confluent kafka topic consume" ${CONSUME_SECONDS}
  confluent kafka topic consume -b confluent-audit-log-events > ${DATADIR}/${ORGANIZATION_NAME}_audit_logs_${DTS}

  LINES=`cat ${DATADIR}/${ORGANIZATION_NAME}_audit_logs_${DTS}|wc -l|sed "s/ //g"`
  echo;echo "(I) ${CONSUME_SECONDS} seconds elapsed. Number of CC Audit logs downloaded for analysis: ${LINES}."
  echo "(I) Now run sh 02_analyze_cc_audit_entries.sh"
  echo;echo

}

GetOrganizationName()
{
  W=${WORKDIR}/GetOrganizationName.out
  confluent organization describe > ${W}
  RET=$?
  if [ "$RET" -eq 0 ]
  then
    ORGANIZATION_NAME=`cat ${W} | grep "Name"|awk -F '|' '{print $3}' | sed "s/ //g"`
    export ORGANIZATION_NAME
    echo "(I) Get Organization Name: ok"
    #!#rm -f ${W}
  else
    echo "(E) Get Organization Name: error:"
    cat ${W} 2>/dev/null
    echo "(E) See https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#access-the-audit-log-user-interface"
    echo; echo "Check and restart ..."
    exit 255
  fi
}

checkDownloadedAuditLogs()
{
  W=${WORKDIR}/checkDownloadedAuditLogs.out
  DOWNLOADS=`ls -1 ${DATADIR}/*audit_logs_202*|wc -l|sed "s/ //g"`
  LATEST=`ls -1 ${DATADIR}/*audit_logs_202*|tail -1`
  echo "(I) the number of downloads for the Confluent Audit Log in ${DATADIR} is ${DOWNLOADS}, and the most recent download is ${LATEST}"
  echo "(I) To download a new file, Ctrl-C and run download_audit_log_entries.sh"
  echo "Hit Return to continue using ${LATEST} or Ctrl-C to cancel"
  read hello
}

#
# starts here
#
echo;echo;echo "${DTS}: Starting download of audit logs"
checkConfluentCliInstalled
checkJqInstalled
checkConfluentCliLoggedIn
GetOrganizationName
ConfluentAuditLogDescribe
ConfluentAuditCheckApiKey
ConsumeAuditTopic
