# Confluent Cloud Audit Logs Analysis

This repo provides bash shell scripts that analyze Audit Log entries for your Confluent Cloud organization.
It runs on MacOS (not on Wondows unfortunately)
It consists of three shell scripts and a sqlite executable.
The database is used to generate crosstab reports for audit logs per day.
The shell scripts are interactive - they require responses. No arguments are provided when running the scripts.

## Pre-requisites
Access to Confluent Cloud audit logs requires the "OrganizationAdmin" RBAC role.
See the Confluent Cloud documentation for setup of the cli before running the scripts in this repo:
https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#consume-with-confluent-cli
The scripts in this repo require a bash shell and have been tested on MacOS.

## Overview
There is no cost associated with this and it does not impact I/O to your Confluent Cloud clusters (Audit data is stored in an entirely different system).
You can run this as frequently as needed (not that there are API call limits on Confluent Cloud clusters).
The reports list the service account names. No other data is listed (including topic names, message contents etc).
It is possible to pipe the results into other systems to automate access checks, service account locking; etc.


## How it works
Run 01_download_audit_log_entries.sh to download audit log entries for your Cloud Organization. These may number in millions of entries: it may take 15-30 minutes to complete.

Run 02_analyze_cc_audit_entries.sh to load the latest downloaded audit log entries into a local sqlite database and run a number of queries to summarize the audit log entries.
Downloaded audit logs (which are json) is retained in the "data" subdiretory.
Generated reports (which are text) are retained in the "reports" subdiretory.
There is one summary report per day (with four sections) and four sub-directories with a daily report for AUTH_EVENTS, OTHER_EVENTS, SIGNIN_FAIL, SIGNIN_SUCCESS.
Files in Data and Reports are timestamped by date so older dates are retained.

Run 03_cleanup to delete the subdirectories and their contents (data, reports, work). They will be automatically recreated for the next download and analyze.


## How to use this
Audit Logs provide a 10,000 foot view of client activity (producers and consiumers) for your Confluent Cloud organization.
If clients are behaving in an unexpected way (such as reconnecting too rapidly) then this could cause instability.
Audit Log entries are generally numerous, so a first round of analysis is to aggregate and count: by prinipal (= username); by method; etc.
If any of the counts appear abnormally high, investigate the clients (producers and consumers) that use the names principal to deterine why.
For example if the kafka.Authentication events for a user-principal are 3600 per hour, then check if clients using this user-principal are expected to reconnect to Confluent Cloud each second.


## Downloading Audit data
```
./01_download_audit_log_entries.sh
(I) check confluent cli installed: ok
Your token has expired. You are now logged out.
(I) check confluent cli logged in: ok
(I) Get Organization Name: ok
(I) Confluent Audit-Log cluster is lkc-xxxxx
(I) Confluent Audit-Log environment is env-xxxxx
Now using "env-xxxxx" as the default (active) environment.
Set Kafka cluster "lkc-xxxxx" as the active cluster for environment "env-xxxxx".
(I) Confluent Audit Log Check Api Key: ok


(I) Downloading Confluent Cloud audit log entries into file ./data/Confluent_audit_logs_20230411160011
(I) Confluent Cloud Audit Logs contain the last 7 days of entries - the number of entries could number hundreds of thousands, or millions
(I) The download is a 'consume' so it will not terminate - in another session, monitor the file (using tail) and Ctrl-C this session whn it has caught up
(I) This generally takes about 10-15 minutes with ~1GB of downloaded data

(I) Downloading Confluent Cloud audit log entries into file ./data/Confluent_audit_logs_20230411160011
(I) Confluent Cloud Audit Logs contain the last 7 days of entries - the number of entries could number hundreds of thousands, or millions
(I) A download generally takes about 5 minutes with ~1GB of downloaded data
(I) The download is a 'consume' so it will not terminate
(I) In another session, monitor the file (using tail -2 ./data/Confluent_audit_logs_20230411160011), and check the 'time' until it catches up ('time' is UTC)
(I) Then Ctrl-C this session to terminate the consumer and complete the download
Starting Kafka Consumer. Use Ctrl-C to exit.
^CStopping Consumer.
(I) Consume Audit topic: ok
```


## Analyzed Confluent Cloud Audit Entries
```
./02_analyze_cc_audit_entries.sh
recreateDatabaseTable (I) drop/create sqlite table cc_audit_events

insertCCAuditEvents (I) Processing Confluent Cloud Audit Events:
(I):   reading    1037696 CC audit logs from ./data/Confluent_audit_logs_20230411160011 to populate ./work/cc_audit_events.csv
(I):   populated   994691 CC audit logs into ./work/cc_audit_events_1.csv for kafka.Authentication & mds.Authorize
(I):   populated    43005 CC audit logs into ./work/cc_audit_events_2.csv for other event types
(I):   populated        0 ERROR lines into ./work/cc_audit_events_ERRORS.txt
(I):   all events 1037696 CC audit logs into ./work/cc_audit_events.csv for all event types

(I):   ./work/cc_audit_events.csv successfully loaded into sqlite

Results written to ./reports/analyze_audit_logs_20230411161159.txt
```

## Cleanup 
./03_cleanup
About to run a cleanup: delete contents of the work/ and data/
These directories are not deleted: (bin,reports)
Hit <return> to continue, or ctrl-c to abort


## Report 
This is a typical report of Confluent Cloud Audit entries
```


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   MDS Authorize Events                                                                                       
2024-08-18                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23
Principal                                                                                                                                                                     
Principal__________________       __________________________________________________________________________________________________________________________________          
u-8p71o5-AccessMetrics             -     -     -     -     -     -     -     -     -    22     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-Alter                     -     -     -     -     -     -     -     -     -    17     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-AlterAccess               -     -     -     -     -     -     -     -     -     8     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-Create                    -     -     -     -     -     -     -     -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-CreateEnvironment         -     -     -     -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-CreateFlinkComputePoo     -     -     -     -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-CreateSRCluster           -     -     -     -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-Delete                    -     -     -     -     -     -     -     -     -     3     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-Describe                  -     -     -     -     -     -     -     -     -   173     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-DescribeAccess            -     -     -     -     -     -     -     -     -     6     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-Invite                    -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-8p71o5-View                      -     -     -     -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -





line                                                                                                                                                                          
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   Sign-In Failure Events                                                                                     

Principal__________________       __________________________________________________________________________________________________________________________________          






------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   Sign-In Success Events                                                                                     
2024-08-18                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23
Principal                                                                                                                                                                     
Principal__________________       __________________________________________________________________________________________________________________________________          
markteehan@streamsend.io           -     -     -     -     -     -     -     -     -     7     -     -     -     -     -     -     -     -     -     -     -     -     -     -






------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   All CC Audit Events                                                                                        
2024-08-18                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23
   Method                                                                                                                                                                     
   Method__________________       ___________________________________________________________________________________________________________________________________________ 
BindRoleForPrincipal               -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateComputePool                  -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateStatement                    -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateUser                         -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateWorkspace                    -     -     -     -     -     -     -     -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -
DeleteWorkspace                    -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetAPIKeys                         -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetComputePool                     -     -     -     -     -     -     -     -     -    64     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetConnectors                      -     -     -     -     -     -     -     -     -     8     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetEnvironment                     -     -     -     -     -     -     -     -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetEnvironments                    -     -     -     -     -     -     -     -     -    48     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetInvitations                     -     -     -     -     -     -     -     -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetKSQLClusters                    -     -     -     -     -     -     -     -     -     6     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetKafkaClusters                   -     -     -     -     -     -     -     -     -    32     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetNetworks                        -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetPeerings                        -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetPrivateLinkAccesses             -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetPrivateLinkAttachments          -     -     -     -     -     -     -     -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetSchemaRegistryClusters          -     -     -     -     -     -     -     -     -     6     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetServiceAccount                  -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetServiceAccounts                 -     -     -     -     -     -     -     -     -     6     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetStatement                       -     -     -     -     -     -     -     -     -   248     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetTransitGateways                 -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetUsers                           -     -     -     -     -     -     -     -     -     8     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetWorkspace                       -     -     -     -     -     -     -     -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GrantRoleResourcesForPrincipal     -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
InviteUser                         -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListComputePools                   -     -     -     -     -     -     -     -     -    50     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListFlinkRegions                   -     -     -     -     -     -     -     -     -    10     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListIdentityProvider               -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListPipelines                      -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListSchemaRegistryClusters         -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListStatements                     -     -     -     -     -     -     -     -     -   300     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListWorkspaces                     -     -     -     -     -     -     -     -     -   100     -     -     -     -     -     -     -     -     -     -     -     -     -     -
SignIn                             -     -     -     -     -     -     -     -     -    14     -     -     -     -     -     -     -     -     -     -     -     -     -     -
flink.Authenticate                 -     -     -     -     -     -     -     -     -   682     -     -     -     -     -     -     -     -     -     -     -     -     -     -
flink.Authorize                    -     -     -     -     -     -     -     -     -   288     -     -     -     -     -     -     -     -     -     -     -     -     -     -
mds.Authorize                      -     -     -     -     -     -     -     -     -   478     -     -     -     -     -     -     -     -     -     -     -     -     -     -
schema-registry.Authentication     -     -     -     -     -     -     -     -     -    80     -     -     -     -     -     -     -     -     -     -     -     -     -     -
schema-registry.GetEntityByTyp     -     -     -     -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
schema-registry.GetQuery           -     -     -     -     -     -     -     -     -    24     -     -     -     -     -     -     -     -     -     -     -     -     -     -


