# Confluent Cloud Audit Logs Analysis

This repo provides bash shell scripts that analyze Audit Log entries for your Confluent Cloud organization.
It runs on MacOS (not on unfortunately)
It consists of three shell scripts and a sqlite executable.
The shell scripts are interactive - they require responses. No arguments are provided when running the scripts.

## Pre-requisites
Access to Confluent Cloud audit logs requires the "OrganizationAdmin" RBAC role.
See the Confluent Cloud documentation for setup of the cli before running the scripts in this repo:
https://docs.confluent.io/cloud/current/monitoring/audit-logging/configure.html#consume-with-confluent-cli
The scripts in this repo require a bash shell and have been tested on MacOS.

## How it works
Run 01_download_audit_log_entries.sh to download audit log entries for your Cloud Organization. These may number in millions of entries: it may take 15-30 minutes to complete.

Run 02_analyze_cc_audit_entries.sh to load the latest downloaded audit log entries into a local sqlite database and run a number of queries to summarize the audit log entries.

Run 03_cleanup to delete the subdirectories and their contents (data, work). They will be automatically recreated for the next download and analyze.

The query results are written into the reports sub directory using unique filenames for each execution (so that you can diff the files)

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

cat reports/analyze_audit_logs_20230411161159.txt
  Run at : 20230411161159
  ---------------------------------------------
  Loading Audit events for kafka.Authentication
                             mds.Authorize

 Ignoring Audit events for other methods


#
# Confluent Cloud Audit Log Contents: start/end date for Audit Logs, the count of audit log entries by method by principal (username)
#
audit_start_time                                    audit_end_time
--------------------------------------------------  ------------------------------
2023-04-04T04:24:36.481804981Z                      2023-04-11T08:05:36.406804015Z


method                                              number_of_audit_entries
--------------------------------------------------  -----------------------
mds.Authorize                                       989343
schema-registry.Authentication                      22318
GetKafkaClusters                                    6053
kafka.Authentication                                5348
GetSchemaRegistryClusters                           3511
GetConnectors                                       3361
GetNetworks                                         1651
GetTransitGateways                                  1618
GetPeerings                                         1371
GetKSQLClusters                                     1144
SignIn                                              791
GetConnector                                        424
RegisterSchema                                      167
GetServiceAccounts                                  87
GetEnvironments                                     86
GetEnvironment                                      84
GetKafkaCluster                                     80
GetUsers                                            75
SearchCatalogUsingAttributes                        35
UpdateUser                                          18
DeleteSubject                                       16
GetServiceAccount                                   15
CreateServiceAccount                                11
CreateAPIKey                                        11
DeleteServiceAccount                                10
CreateConnector                                     9
DeleteAPIKey                                        7
UnbindAllRolesForPrincipal                          6
GetAPIKeys                                          6
DeleteKafkaCluster                                  6
LookUpSchemaUnderSubject                            5
DeleteConnector                                     5
CreateOrUpdateConnector                             5
CreateKafkaCluster                                  5
ListPipelines                                       4
GetInvitations                                      3
DeleteEnvironment                                   2
CreateKSQLCluster                                   2
GetAPIKey                                           1
CreateSchemaRegistryCluster                         1
CreateEnvironment                                   1



principal                                           audit_entries_per_username
--------------------------------------------------  --------------------------
User:sa-xxxxxx                                      819107
User:u-xxxxxx                                       100788
                                                    43005
User:u-xxxxxx                                       11677
User:u-xxxxxx                                       11323
User:u-xxxxxx                                       9320
User:u-xxxxxx                                       7241
User:u-xxxxxx                                       6585
User:u-xxxxxx                                       6305
User:999999                                         5137
User:u-xxxxxx                                       4107
User:u-xxxxxx                                       3421
User:u-xxxxxx                                       3245
User:u-xxxxxx                                       2328
User:u-xxxxxx                                       1922
User:u-xxxxxx                                       1512
User:flowserviceadmin                               440
User:999999                                         118
User:999999                                         45
User:9999999                                        30
User:9999999                                        14
User:schemaregistryconnectadmin                     9
User:notificationserviceadmin                       9
User:999999                                         3
User:schemaregistryvalidationadmin                  2
User:ksqlscheduleradmin                             2
None:UNKNOWN_USER                                   1

#
# Analyze kafka.Authentication events. Find the busiest day (most audit events) and show the number of auth  events per principal per hour for 24 hours
#
line
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                      Kafka Authentication Events For one Day (the day with the most Audit Data)
2023-04-10       Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23
Principal
   Logins________       ____________________________________________________________________________________________________________________________________________
User:999999             30    30    30    30    30    30    30    30    30    39    30    30    30    30    30    30    30    30    30    30    30    30    30    30
User:999999              -     -     -     -     -     -    44     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -

#
# Analyze mds.Authorize events. Find the busiest day and show the number of MDS Authorization Requests per principle per Operation
#
line
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                            MDS Authorize Events For one Day (the day with the most Audit Data)
2023-04-10                 Hour:  00    01    02    03    04    05    06    07    08    09    10    11    12    13    14    15    16    17    18    19    20    21    22    23
Principal
   Logins________                 ____________________________________________________________________________________________________________________________________________
flowserviceadmin-Alter             -     -     -     -     -   144     -     -    74     -     -     -     -    74     -     -     -     -     -     -     -     -     -     -
ksqlscheduleradmin-Alter           -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
sa-xxxxx-AccessMetrics         4477  4370  4758  4636  5246  4779  4710  4625  5252  5025  5166  5040  4662  4398  4875  5000  5000  5125  5125  5000  4625  5250  5625  5250
schemaregistryconnectadmin-Alt     -     -     -     -     -     3     -     -     1     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -
schemaregistryvalidationadmin-     -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AccessMetrics             -     -   732   366     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AccessWithToken           -     -   168   168     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Alter                     -     -    35     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ConfigureKafkaCredent     -     -   132     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Create                    -     -     4     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateCloudCluster        -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateEnvironment         -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateSRCluster           -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Delete                    -     -    23     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Describe                  -     -   837   108     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-View                      -     -    12     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AccessMetrics           968  3166  4270   244     -   984  3348   750  3005  6531     -     -     -  3256   625  1625   375     -     -     -     -     -     -     -
u-xxxxxx-AccessWithToken          56   616   336    56     -   112   228   174   232   638    58     -     -   232   116   290   406   232    58     -     -     -     -     -
u-xxxxxx-Alter                    36    19    38     -     -    37     -     -    52    48     -     -     -    62     -    42     -     -     -     -     -     -     -     -
u-xxxxxx-Configure                 -    15    11     -     -     1     -     -    14    22     -     -     -     8     -     1     -     -     -     -     -     -     -     -
u-xxxxxx-ConfigureKafkaCredent   136   216   314     -     -   144   134     -   240   641     -     -     -   440     -   134   134     -     -     -     -     -     -     -
u-xxxxxx-Contribute                -     -     -     -     -     -     1     -     1     1     -     -     -     2     -     1     -     -     -     -     -     -     -     -
u-xxxxxx-Create                    7     9     9     -     -     7     2     -    13     8     -     -     -    14     -    10     -     -     -     -     -     -     -     -
u-xxxxxx-CreateCloudCluster        2     1     2     -     -     2     -     -     3     2     -     -     -     4     -     2     -     -     -     -     -     -     -     -
u-xxxxxx-CreateEnvironment         1     -     1     -     -     1     -     -     1     1     -     -     -     1     -     1     -     -     -     -     -     -     -     -
u-xxxxxx-CreateKsqlCluster         -     1     -     -     -     -     2     -     1     1     -     -     -     2     -     1     -     -     -     -     -     -     -     -
u-xxxxxx-CreateSRCluster           1     1     1     -     -     2     -     -     4     4     -     -     -     6     -     2     -     -     -     -     -     -     -     -
u-xxxxxx-Delete                   26    12    32     -     -    30     -     -    36    34     -     -     -    36     -    28     -     -     -     -     -     -     -     -
u-xxxxxx-Describe                793  1880  1450    22     -   843   535    84  1646  2496    51     -     -  2339    43  1480   290    12     4     -     -     -     -     -
u-xxxxxx-Pause                     -     6     4     -     -     2     -     -     8     2     -     -     -     4     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ReadConfig                -     5     4     -     -     2     -     -     7     1     -     -     -     4     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ReadStatus                -    31    11     -     -     5     -     -    30    10     -     -     -     8     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Resume                    -     6     4     -     -     2     -     -     8     2     -     -     -     4     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Terminate                 -     -     -     -     -     -     1     -     1     1     -     -     -     2     -     1     -     -     -     -     -     -     -     -
u-xxxxxx-ValidateConfig            -    11     8     -     -     -     -     -    10    15     -     -     -     4     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-View                     11     7    17     -     -    11     5     -    15    20     -     -     -    22     -    10     6     -     -     -     -     -     -     -
u-xxxxxx-AccessWithToken           -     -     -     -     -     -     -     -     -     -     -     -     -   116     -     -    58     -     -     -     -     -     -     -
u-xxxxxx-Alter                     -     -     -     -     -     -     -     -     -     -     -     -     -     8     -     -     4     -     -     -     -     -     -     -
u-xxxxxx-Create                    -     -     -     -     -     -     -     -     -     -     -     -     -     4     -     -     2     -     -     -     -     -     -     -
u-xxxxxx-Delete                    -     -     -     -     -     -     -     -     -     -     -     -     -     4     -     -     2     -     -     -     -     -     -     -
u-xxxxxx-Describe                  -     -     -     -     -     -     -     -     -     -     -     -     -   934     -     -   380     -     -     -     -     -     -     -
u-xxxxxx-AccessMetrics             -     -     -     -     -     -  3720     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AccessWithToken           -     -     -     -     -     -   342     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Alter                     -     -     -     -     -     -    89     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AlterAccess               -     -     -     -     -     -     5     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ConfigureKafkaCredent     -     -     -     -     -     -   268     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Create                    -     -     -     -     -     -    22     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateCloudCluster        -     -     -     -     -     -    12     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateEnvironment         -     -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateSRCluster           -     -     -     -     -     -     9     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Delete                    -     -     -     -     -     -    51     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Describe                  -     -     -     -     -     -  3083     6     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-DescribeAccess            -     -     -     -     -     -     3     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Invite                    -     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-View                      -     -     -     -     -     -    19     5     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AccessMetrics             -     -     -     -     -  3186   369     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-AccessWithToken           -     -     -    56     -   168   113     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Alter                     -     -     -     -     -    39     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Configure                 -     -     -     -     -    24     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ConfigureKafkaCredent     -     -     -     -     -   255     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Create                    -     -     -     -     -    12     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateCloudCluster        -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateEnvironment         -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-CreateSRCluster           -     -     -     -     -     1     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Delete                    -     -     -     -     -    32     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Describe                  -     -     -    43     -  1125    44     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Pause                     -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ReadConfig                -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ReadStatus                -     -     -     -     -    56     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-Resume                    -     -     -     -     -     2     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-ValidateConfig            -     -     -     -     -    21     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -
u-xxxxxx-View                      -     -     -     -     -    13     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -     -

```
