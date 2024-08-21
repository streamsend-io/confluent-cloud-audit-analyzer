# Confluent Cloud Audit Logs Analysis

This repo provides bash shell scripts that analyze Audit Log entries for your Confluent Cloud organization.
It runs on MacOS (not on Wondows unfortunately)
It consists of three shell scripts and a sqlite executable.
The database is used to generate crosstab reports for Confluent Cloud audit logs per day.
The shell scripts do not requires any responses, so they can be cron'd.

## Pre-requisites
Access to Confluent Cloud audit logs requires the "OrganizationAdmin" RBAC role.
See the Confluent Cloud documentation for setup of the cli before running the scripts in this repo:
https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#consume-with-confluent-cli
The scripts in this repo require a bash shell and have been tested on MacOS.

## Is it free?
Yes. There is no cost associated with using these scripts. 
Retrieving Audit records from Confluent Cloud does not impact I/O to your Confluent Cloud clusters (Audit data is stored in an entirely different system).
Confluent Cloud retains data for several days: I recommend to run this once daily: daily reports are retained as local text files. 


## Do Audit Reports contain sensitive data?
No. The audit subsystem does not contain any business data.
The reports list the Confluent Cloud service account names. No other data is listed (including topic names, message contents etc).


## Reports are dull - what else can I do?
It is possible to modify the scripts to pipe query results into other systems to automate access checks, service account locking; etc.


## How it works
The Confluent Cloud Audit API endpoint for your organization is queried for all data, which is downloaded as json.
This is parsed and loaded into sqlite, using four tables.
After checking the earliest date, and number of days in the data, a series of queries generate daily crosstab reports, which are stored in the "reports" subdirectory.


## Operation
Run 01_download_audit_log_entries.sh to download audit log entries for your Cloud Organization. These may number in millions of entries: it may take ~5  minutes to complete.


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


## Analyze Confluent Cloud Audit Entries
```
./02_analyze_cc_audit_entries.sh
```
recreateDatabaseTable (I) drop/create sqlite table AUTH_EVENTS
(I):   populated      900 CC audit logs into ./work/AUTH_EVENTS.csv for kafka.Authentication & mds.Authorize
(I):   populated        7 CC audit logs into ./work/SIGNIN_FAIL.csv for SignIn Fail
(I):   populated       69 CC audit logs into ./work/SIGNIN_FAIL.csv for SignIn Success
(I):   populated   161207 CC audit logs into ./work/OTHER_EVENTS.csv for other event types

Audit Summary for 161207 events spanning 6 days from 2024-08-15
2024-08-15:(62069 events) 2024-08-16:(0 events) 2024-08-17:(1104 events) 2024-08-18:(97594 events) 2024-08-19:(0 events) 2024-08-20:(0 events) 2024-08-21:(440 events)

See /reports for daily audit reports



## Cleanup 
./03_cleanup
About to run a cleanup: delete contents of the work/ and data/
These directories are not deleted: (bin,reports)
Hit <return> to continue, or ctrl-c to abort


## Report 
This is a typical report of Confluent Cloud Audit entries
### How to read this:
Between 9am and 10am on 18/Aug/2024, service account u-8p71o5 logged 22 "AccessMetrics" audit events. 

### Audit report for 18/Aug/2024 in four sections (MDS Authorize Events, Sign-In Failure Events (no data), Sign-In Success Events, All CC Audit Events)
Note that  "All CC Audit Events" counts Audit Events per hour: there is no breakdown by service account.
```


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   MDS Authorize Events                                                                                       
2024-08-18                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23

Principal__________________       ____________________________________________________________________________________________________________________________________________
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

Principal__________________       ____________________________________________________________________________________________________________________________________________






------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   Sign-In Success Events                                                                                     
2024-08-18                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23

Principal__________________       ____________________________________________________________________________________________________________________________________________
markteehan@streamsend.io           -     -     -     -     -     -     -     -     -     7     -     -     -     -     -     -     -     -     -     -     -     -     -     -






------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                   All CC Audit Events
2024-08-18                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23
___________________________       ____________________________________________________________________________________________________________________________________________
BindRoleForPrincipal               -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateAPIKey                       -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
CreateComputePool                  -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateEnvironment                  -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
CreateServiceAccount               -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
CreateStatement                    -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateUser                         -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
CreateWorkspace                    -     -     -     -     -     -     -     -     -   116     -     -     -     -     -     -     -     -     -     -     -     -     -     -
DeleteInvitation                   -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
DeleteUser                         -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
DeleteWorkspace                    -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetAPIKeys                         -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -   168     -     -     -     -
GetComputePool                     -     -     -     -     -     -     -     -     -  1856     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetConnectors                      -     -     -     -     -     -     -     -     -   232     -     -     -     -     -     -     -     -     -   168     -     -     -     -
GetEnvironment                     -     -     -     -     -     -     -     -     -   116     -     -     -     -     -     -     -     -     -   168     -     -     -     -
GetEnvironments                    -     -     -     -     -     -     -     -     -  1392     -     -     -     -     -     -     -     -     -   728     -     -     -     -
GetInvitation                      -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetInvitations                     -     -     -     -     -     -     -     -     -   116     -     -     -     -     -     -     -     -     -   112     -     -     -     -
GetKSQLClusters                    -     -     -     -     -     -     -     -     -   174     -     -     -     -     -     -     -     -     -   168     -     -     -     -
GetKafkaCluster                    -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetKafkaClusters                   -     -     -     -     -     -     -     -     -   928     -     -     -     -     -     -     -     -     -   672     -     -     -     -
GetNetworks                        -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -   168     -     -     -     -
GetPeerings                        -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetPrivateLinkAccesses             -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetPrivateLinkAttachments          -     -     -     -     -     -     -     -     -   116     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetSchemaRegistryClusters          -     -     -     -     -     -     -     -     -   174     -     -     -     -     -     -     -     -     -   168     -     -     -     -
GetServiceAccount                  -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetServiceAccounts                 -     -     -     -     -     -     -     -     -   174     -     -     -     -     -     -     -     -     -   336     -     -     -     -
GetStatement                       -     -     -     -     -     -     -     -     -  7192     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GetTransitGateways                 -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -    56     -     -     -     -
GetUsers                           -     -     -     -     -     -     -     -     -   232     -     -     -     -     -     -     -     -     -   280     -     -     -     -
GetWorkspace                       -     -     -     -     -     -     -     -     -   116     -     -     -     -     -     -     -     -     -     -     -     -     -     -
GrantRoleResourcesForPrincipal     -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -    56     -     -     -     -
InviteUser                         -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListComputePools                   -     -     -     -     -     -     -     -     -  1450     -     -     -     -     -     -     -     -     -   448     -     -     -     -
ListCustomConnectorPlugins         -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -   168     -     -     -     -
ListFlinkRegions                   -     -     -     -     -     -     -     -     -   290     -     -     -     -     -     -     -     -     -    56     -     -     -     -
ListIdentityProvider               -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListPipelines                      -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListSchemaRegistryClusters         -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -   224     -     -     -     -
ListStatements                     -     -     -     -     -     -     -     -     -  8700     -     -     -     -     -     -     -     -     -     -     -     -     -     -
ListWorkspaces                     -     -     -     -     -     -     -     -     -  2900     -     -     -     -     -     -     -     -     -     -     -     -     -     -
SignIn                             -     -     -     -     -     -     -     -     -   798   392     -     -     -     -     -     -     -     -   224     -     -     -     -
UnbindAllRolesForPrincipal         -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
UpdateAPIKey                       -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -   112     -     -     -     -
flink.Authenticate                 -     -     -     -     -     -     -     -     - 19778     -     -     -     -     -     -     -     -     -     -     -     -     -     -
flink.Authorize                    -     -     -     -     -     -     -     -     -  8352     -     -     -     -     -     -     -     -     -     -     -     -     -     -
mds.Authorize                      -     -     -     -     -     -     -     -     - 13862     -     -     -     -     -     -     -     -     - 12880     -     -     -     -
schema-registry.Authentication     -     -     -     -     -     -     -     -     -  2320     -     -     -     -     -     -     -     -     -  3584     -     -     -     -
schema-registry.CreateTagDefs      -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -   224     -     -     -     -
schema-registry.GetAllTagDefs      -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -   672     -     -     -     -
schema-registry.GetEntityByTyp     -     -     -     -     -     -     -     -     -    58     -     -     -     -     -     -     -     -     -   168     -     -     -     -
schema-registry.GetQuery           -     -     -     -     -     -     -     -     -   696     -     -     -     -     -     -     -     -     -   896     -     -     -     -
schema-registry.GetTagDefsAndE     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -    56     -     -     -     -
schema-registry.RegisterSchema     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -   224     -     -     -     -
schema-registry.SearchCatalogU     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -   280     -     -     -     -

