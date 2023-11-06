#!/bin/bash
cluster={HOST.NAME}
host1={$BROKER1}
host2={$BROKER2}
host3={$BROKER3}

echo "Cluster is " $cluster
echo "BROKER1 is " $host1
echo "BROKER2 is " $host2
echo "BROKER3 is " $host3

Dash_name="MSK"
auth="{$ZABBIX_AUTH}"
#zabbix_url="{$ZABBIX_URL}"
zbx_host="{$ZABBIX_HOST}"
zabbix_url="https://${zbx_host}/api_jsonrpc.php"
echo $zabbix_url
existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "output": ["name", "dashboardid"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
data_file="/tmp/zabbix_dash.json"
rm $data_file

Get_UserGroup_Ids() {
    # call this functin like - Get_UserGroup_Ids "${GROUP_NAMES[@]}"
    GROUP_IDS=()
    for NAME in "${@}"; do
        ID=$(curl -s -k -X POST -H "Content-Type: application/json-rpc" -d '{
"jsonrpc": "2.0",
"method": "usergroup.get",
"params": {
"filter": {
"name": "'${NAME}'"
}
},
"auth": "'${auth}'",
"id": 1
}' ${zabbix_url}/api_jsonrpc.php | grep -o '"usrgrpid":[^,}]*' | cut -d ":" -f2 | tr -d '"')
        GROUP_IDS+=("${ID}")
    done
    echo "Requeted Group Ids: ${GROUP_IDS[@]} for dash access"
}
#Get_UserGroup_Ids "${GROUP_NAMES[@]}"

Get_Dash_CurrentNRequested_Sharing() {
    # call this function like Get_Dash_CurrentNRequested_Sharing <dash-id> "${<ListofGroupVariable[@]}"
    DASHBOARD_ID=$1
    shift 1
    CURRENT_SHARING=$(curl -s -k -X POST -H "Content-Type: application/json-rpc" -d '{
"jsonrpc": "2.0",
"method": "dashboard.get",
"params": {
"output": "extend",
"selectUsers": "extend",
"selectUserGroups": "extend",
"filter": {
"dashboardid": '${DASHBOARD_ID}'
}
},
"auth": "'${auth}'",
"id": 1
}' ${zabbix_url}/api_jsonrpc.php | tee /tmp/dash-sharing | grep -o '"usrgrpid":[^,}]*' | cut -d ":" -f2 | tr -d '"')
    echo "Existing UserGroup access for dash id: $DASHBOARD_ID are group ids: $CURRENT_SHARING"
    #Get group ids

    #Get_UserGroup_Ids "${GROUP_NAMES[@]}"
    Get_UserGroup_Ids "$@"
    for x in $CURRENT_SHARING; do
        GROUP_IDS+=("${x}")
    done
    echo "List from current and requested : ${GROUP_IDS[@]}"

    remove_dup() {
        echo $1 | tr ' ' '\n' | sort -u | tr '\n' ' '
    }
    UniqGroups=${GROUP_IDS[@]}
    UniqGroupsids=$(remove_dup "$UniqGroups")
    UniqGroupsidss=$(echo $UniqGroupsids | sed "s/[']//g")
    for y in $UniqGroupsidss; do
        GROUP_IDS_U+=("${y}")
    done
    echo "Final list of groups ids: ${GROUP_IDS_U[@]}"
    ########################
    NEW_GROUP_JSON=$(printf '{"usrgrpid":"%s","permission":"2"},' "${GROUP_IDS_U[@]}")
    #NEW_GROUP_JSON=$(printf '{"usrgrpid": %s, "permission": "2"},' "${UniqGroupsidss}")
    NEW_GROUP_JSON="[${NEW_GROUP_JSON%,}]"
    echo "${NEW_GROUP_JSON}" >/tmp/dash-out
    ## Updare sharing groups
    echo "" >/tmp/dash-updatePermGroup.sh
    for x in $(cat /tmp/dash-sharing | grep -o '"usrgrpid":[^}]*' | grep -v '"permission":"2"'); do
        xx=$(echo $x | grep -o '"usrgrpid":[^,}]*')
        echo "sed -i -e 's/$xx,\"permission\":\"2\"/$x/g' /tmp/dash-out" | tee -a /tmp/dash-updatePermGroup.sh
        xx=""
    done
    echo "Following group's permission are diffrent than ReadOnly"
    echo "$(cat /tmp/dash-sharing | grep -o '"usrgrpid":[^}]*' | grep -v '"permission":"2"')"
    sh /tmp/dash-updatePermGroup.sh
    Get_Dash_CurrentNRequested_Sharing_JOUT=$(cat /tmp/dash-out)

    #echo $NEW_GROUP_J_OUT
    sleep 2
    GROUP_IDS=""
    rm -rf /tmp/dash-updatePermGroup.sh /tmp/dash-out /tmp/dash-sharing
    ## Call this funtions like below
    ## Get_Dash_CurrentNRequested_Sharing <Dash id> "${ArrayVariable[@]}" <more groups>
    ## Array varible will define like - Dash_Sharing_Group=("Group1" "Group2" "etc")
    ## i.e Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_default_Sharing_Group[@]}" "${Dash_Sharing_Group[@]}"
    ## Once done you have to use "Get_Dash_CurrentNRequested_Sharing_JOUT" variable in userGroups value
    ## "userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"' ###
}

if [ $cluster = "cluster.msk-sit" ]; then
    Dash_name="SIT MSK"
    env="sit"
    host_group="sit.bcs-Servers"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly" "p-ped-zabbix-nprod-admins")
elif [ $cluster = "cluster.msk-ppe1" ]; then
    Dash_name="PPE1 MSK"
    env="ppe1"
    host_group="ppe.bcs-Servers"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly" "p-ped-zabbix-nprod-admins")
elif [ $cluster = "cluster.msk-ppe2" ]; then
    Dash_name="PPE2 MSK"
    env="ppe2"
    host_group="ppe.bcs-Servers"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly" "p-ped-zabbix-nprod-admins")
elif [ $cluster = "cluster.msk-ppe3" ]; then
    Dash_name="PPE3 MSK"
    env="ppe3"
    host_group="ppe.bcs-Servers"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly" "p-ped-zabbix-nprod-admins")
elif [ $cluster = "cluster.msk-express" ]; then
    Dash_name="Express MSK Non Prod"
    env="express-np"
    host_group="express"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-admins" "p-ped-zabbix-nprod-express")
elif [ $cluster = "cluster.msk-expressPerf" ]; then
    Dash_name="Express Performance Testing MSK"
    env="expressPerf"
    host_group="express"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-admins" "p-ped-zabbix-nprod-express")
else
    echo "Not running"
    exit 1
fi

items_per_topic_list="SUM Bytes in Per Topic;SUM Bytes out Per Topic;SUM InSyncReplicasCount;AVG Consumer Lag Metrics - MaxOffsetLag;AVG Consumer Lag Metrics - OffsetLag;AVG Consumer Lag Metrics - EstimatedMaxTimeLag;SUM Produce Request per sec Per Topic;SUM Fetch Request per sec Per Topic;SUM Messages in Per Topic;AVG Log size Per Topic"
itens_per_listener_list=""
items_per_broker_list="Broker Network throughput - bytes / second;Bytes out per broker;Online Partitions per broker;Outgoing bytes total - CLIENT_SASL_SCRAM;Outgoing bytes total - Replication;Outgoing bytes total - Replication Secure;Request Handler AVG Idle Percent;Network Processor AVG Idle Percent;Zookeeper Request Latency;Log size per broker;Connections close rate per instance;Connections count per broker;Connections creation rate per instance"
get_host_group=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "hostgroup.get","params": {"output": ["groupid"], "filter": {"name": ["'$host_group'"]}}, "auth": "'$auth'", "id": 1}' "$zabbix_url")
group_id=$(echo $get_host_group | grep -o '"groupid":"[^"]*"' | cut -d ":" -f2 | tr -d '"')

case ${existing_dash} in

*"${Dash_name}"*)
    echo "The existing dashboards are:" $existing_dash
    dash_id=$(echo $existing_dash | grep -o "{[^}]*$Dash_name*" | cut -d ":" -f2 | grep -Eo '[0-9]{1,10}')
    echo dash id is $dash_id

    dash_info=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "dashboardids": ["'$dash_id'"], "selectPages": "extend", "output": "extend"},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
    page_id=$(echo $dash_info | grep -o '"dashboard_pageid":"[^"]*' | cut -d ":" -f2 | tr -d '"')
    echo "Page id is " $page_id

    Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_Sharing_Group[@]}"
    json_part1='{"jsonrpc": "2.0","method": "dashboard.update","params": {"dashboardid": "'$dash_id'","userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"',"pages": [{"dashboard_pageid": "'$page_id'","widgets": ['
    echo -n "$json_part1" >>$data_file

    ;;
*)
    Get_Dash_CurrentNRequested_Sharing na "${Dash_Sharing_Group[@]}"
    json_part1='{"jsonrpc":"2.0","method":"dashboard.create","params":{"name":"'$Dash_name'","userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"',"userid":"1","private":"1","display_period":10,"auto_start":1,"pages":[{"widgets":['
    echo -n "$json_part1" >>$data_file
    ;;
esac

get_hosts=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "host.get","params": {"output": ["items"], "groupids": ["'$group_id'"], "selectTags": "extend","evaltype": 0,"tags": [{"tag": "msk","value": "'$env'","operator": 0}]},"auth": "'$auth'","id": 1}' "$zabbix_url")

hostid=$(echo $get_hosts | grep -o '"hostid":"[^"]*' | grep -Eo '[0-9]{1,10}')

topics=""
for i in $(echo $hostid); do

    items=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$i'","search": {"key_": "messages["},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
    #topics+="$(echo "${items}" | grep -Eo 'in [^"]*' | cut -d " " -f2)" #not working on zabbix
    topics="$topics $(echo "${items}" | grep -Eo 'in [^"]*' | cut -d " " -f2)"
done

unique_topics=$(echo $topics | tr ' ' '\n' | sort -u | tr '\n' ' ')

#################MSK
json_msk='{"type":"tophosts","name":"MSK","x":"5","y":"0","width":"18","height":"3","view_mode":"0","fields":[{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columnsthresholds.color.2.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"90"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.12","value":"Under Replicated Partitions"},{"type":"0","name":"columns.data.12","value":"1"},{"type":"1","name":"columns.item.12","value":"Under Replicated Partitions"},{"type":"1","name":"columns.timeshift.12","value":""},{"type":"0","name":"columns.aggregate_function.12","value":"0"},{"type":"0","name":"columns.display.12","value":"1"},{"type":"0","name":"columns.history.12","value":"1"},{"type":"1","name":"columns.base_color.12","value":""},{"type":"1","name":"columns.name.13","value":"Under Min ISR Partitions"},{"type":"0","name":"columns.data.13","value":"1"},{"type":"1","name":"columns.item.13","value":"Under Min ISR Partitions"},{"type":"1","name":"columns.timeshift.13","value":""},{"type":"0","name":"columns.aggregate_function.13","value":"0"},{"type":"0","name":"columns.display.13","value":"1"},{"type":"0","name":"columns.history.13","value":"1"},{"type":"1","name":"columns.base_color.13","value":""},{"type":"1","name":"columns.name.2","value":"CPU"},{"type":"1","name":"columns.item.2","value":"Cpu Usage"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"1","name":"columns.item.3","value":"Filesystem utilisation percentage"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"1","name":"columns.base_color.3","value":"80FF00"},{"type":"1","name":"columns.name.4","value":"Total requests per second"},{"type":"1","name":"columns.item.4","value":"Total requests per second"},{"type":"1","name":"columns.name.5","value":"Produce Request per Sec"},{"type":"1","name":"columns.item.5","value":"Produce Request per Sec"},{"type":"1","name":"columns.name.6","value":"Fetch Request per Sec"},{"type":"1","name":"columns.item.6","value":"Fetch Request per Sec"},{"type":"1","name":"columns.name.7","value":"Offset Commit Request per Sec"},{"type":"1","name":"columns.item.7","value":"Offset Commit Request per Sec"},{"type":"1","name":"columns.name.8","value":"Metadata request per sec"},{"type":"1","name":"columns.item.8","value":"Metadata request per sec"},{"type":"1","name":"columns.name.9","value":"Unclean Leader Election Rate"},{"type":"1","name":"tags.tag.0","value":"msk"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$env'"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"Active Controller"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"Active Controller Count"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"1"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.base_color.1","value":""},{"type":"1","name":"columnsthresholds.color.1.0","value":"00FFFF"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"0"},{"type":"1","name":"columnsthresholds.color.1.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"1"},{"type":"0","name":"columns.data.2","value":"1"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"0","name":"columns.data.6","value":"1"},{"type":"1","name":"columns.timeshift.6","value":""},{"type":"0","name":"columns.aggregate_function.6","value":"0"},{"type":"0","name":"columns.display.6","value":"1"},{"type":"0","name":"columns.history.6","value":"1"},{"type":"1","name":"columns.base_color.6","value":""},{"type":"0","name":"columns.data.7","value":"1"},{"type":"1","name":"columns.timeshift.7","value":""},{"type":"0","name":"columns.aggregate_function.7","value":"0"},{"type":"0","name":"columns.display.7","value":"1"},{"type":"0","name":"columns.history.7","value":"1"},{"type":"1","name":"columns.base_color.7","value":""},{"type":"0","name":"columns.data.8","value":"1"},{"type":"1","name":"columns.timeshift.8","value":""},{"type":"0","name":"columns.aggregate_function.8","value":"0"},{"type":"0","name":"columns.display.8","value":"1"},{"type":"0","name":"columns.history.8","value":"1"},{"type":"1","name":"columns.base_color.8","value":""},{"type":"0","name":"columns.data.9","value":"1"},{"type":"1","name":"columns.timeshift.9","value":""},{"type":"0","name":"columns.aggregate_function.9","value":"0"},{"type":"0","name":"columns.display.9","value":"1"},{"type":"0","name":"columns.history.9","value":"1"},{"type":"1","name":"columns.base_color.9","value":""},{"type":"0","name":"columns.data.10","value":"1"},{"type":"1","name":"columns.timeshift.10","value":""},{"type":"0","name":"columns.aggregate_function.10","value":"0"},{"type":"0","name":"columns.display.10","value":"1"},{"type":"0","name":"columns.history.10","value":"1"},{"type":"1","name":"columns.base_color.10","value":""},{"type":"0","name":"columns.data.11","value":"1"},{"type":"1","name":"columns.timeshift.11","value":""},{"type":"0","name":"columns.aggregate_function.11","value":"0"},{"type":"0","name":"columns.display.11","value":"1"},{"type":"0","name":"columns.history.11","value":"1"},{"type":"1","name":"columns.base_color.11","value":""},{"type":"0","name":"column","value":"1"},{"type":"1","name":"columns.item.9","value":"Unclean Leader Election Rate"},{"type":"1","name":"columns.name.10","value":"Prefered replica Imbalance"},{"type":"1","name":"columns.item.10","value":"Prefered replica Imbalance"},{"type":"1","name":"columns.name.11","value":"Offline Partition Count"},{"type":"1","name":"columns.item.11","value":"Offline Partition Count"}]},'
echo -n "$json_msk" >>$data_file

#################ITEM TABS
#Broker1 items
brokerid_raw1=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "host.get", "params": {"output": ["hostid"],"filter": {"name": "'$host1'"}}, "id": 2, "auth": "'$auth'"}' "$zabbix_url")
broker1id=$(echo $brokerid_raw1 | grep -o '"hostid":"[^"]*' | grep -Eo '[0-9]{1,10}')
active_brokers_search=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker1id'","search": {"key_": "Active"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
active_brokers=$(echo $active_brokers_search | awk -F 'Active Brokers' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
apache_kafka_java1_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker1id'","search": {"key_": "apache-kafka-java"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
apache_kafka_java1=$(echo $apache_kafka_java1_raw | awk -F 'apache-kafka-java' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
confluent_kafka_dotnet1_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker1id'","search": {"key_": "confluent-kafka-dotnet"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
confluent_kafka_dotnet1=$(echo $confluent_kafka_dotnet1_raw | awk -F 'confluent-kafka-dotnet' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
unknown1_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker1id'","search": {"key_": "unknown"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
unknown1=$(echo $unknown1_raw | awk -F 'unknown' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
online_partitions1_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker1id'","search": {"key_": "online_part"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
online_partitions1=$(echo $online_partitions1_raw | awk -F 'online' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
#arata valoparea variabilelor
#Broker2 items
brokerid_raw2=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "host.get", "params": {"output": ["hostid"],"filter": {"name": "'$host2'"}}, "id": 2, "auth": "'$auth'"}' "$zabbix_url")
broker2id=$(echo $brokerid_raw2 | grep -o '"hostid":"[^"]*' | grep -Eo '[0-9]{1,10}')
apache_kafka_java2_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker2id'","search": {"key_": "apache-kafka-java"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
apache_kafka_java2=$(echo $apache_kafka_java2_raw | awk -F 'apache-kafka-java' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
confluent_kafka_dotnet2_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker2id'","search": {"key_": "confluent-kafka-dotnet"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
confluent_kafka_dotnet2=$(echo $confluent_kafka_dotnet2_raw | awk -F 'confluent-kafka-dotnet' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
unknown2_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker2id'","search": {"key_": "unknown"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
unknown2=$(echo $unknown2_raw | awk -F 'unknown' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
online_partitions2_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker2id'","search": {"key_": "online_part"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
online_partitions2=$(echo $online_partitions2_raw | awk -F 'online' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')

#Broker3 items
brokerid_raw3=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "host.get", "params": {"output": ["hostid"],"filter": {"name": "'$host3'"}}, "id": 2, "auth": "'$auth'"}' "$zabbix_url")
broker3id=$(echo $brokerid_raw3 | grep -o '"hostid":"[^"]*' | grep -Eo '[0-9]{1,10}')
apache_kafka_java3_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker3id'","search": {"key_": "apache-kafka-java"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
apache_kafka_java3=$(echo $apache_kafka_java3_raw | awk -F 'apache-kafka-java' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
confluent_kafka_dotnet3_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker3id'","search": {"key_": "confluent-kafka-dotnet"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
confluent_kafka_dotnet3=$(echo $confluent_kafka_dotnet3_raw | awk -F 'confluent-kafka-dotnet' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
unknown3_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker3id'","search": {"key_": "unknown"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
unknown3=$(echo $unknown3_raw | awk -F 'unknown' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')
online_partitions3_raw=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "item.get","params": {"output": ["name"],"hostids": "'$broker3id'","search": {"key_": "online_part"},"sortfield": "name"},"auth": "'$auth'","id": 1}' "$zabbix_url")
online_partitions3=$(echo $online_partitions3_raw | awk -F 'online' '{print $1;}' | grep -o '"itemid":"[^"]*' | grep -Eo '[0-9]{1,10}')

json_tab_1='{"type":"item","name":"Active Brokers","x":"1","y":"0","width":"4","height":"3","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$active_brokers'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_1" >>$data_file
json_tab_2='{"type":"item","name":"apache-kafka-java Connection/Broker 1","x":"5","y":"3","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$apache_kafka_java1'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_2" >>$data_file
json_tab_3='{"type":"item","name":"apache-kafka-java Connection/Broker 2","x":"11","y":"3","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$apache_kafka_java2'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_3" >>$data_file
json_tab_4='{"type":"item","name":"apache-kafka-java Connection/Broker 3","x":"17","y":"3","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$apache_kafka_java3'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_4" >>$data_file
json_tab_5='{"type":"item","name":"confluent-kafka-dotnet Connection/Broker 1","x":"5","y":"5","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$confluent_kafka_dotnet1'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_5" >>$data_file
json_tab_6='{"type":"item","name":"confluent-kafka-dotnet Connection/Broker 2","x":"11","y":"5","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$confluent_kafka_dotnet2'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_6" >>$data_file
json_tab_7='{"type":"item","name":"confluent-kafka-dotnet Connection/Broker 3","x":"17","y":"5","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$confluent_kafka_dotnet3'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_7" >>$data_file
json_tab_8='{"type":"item","name":"Unknown Connection/Broker 1","x":"5","y":"7","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$unknown1'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_8" >>$data_file
json_tab_9='{"type":"item","name":"Unknown Connection/Broker 2","x":"11","y":"7","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$unknown2'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_9" >>$data_file
json_tab_10='{"type":"item","name":"Unknown Connection/Broker 3","x":"17","y":"7","width":"6","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$unknown3'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_10" >>$data_file
json_tab_11='{"type":"item","name":"Online Partitions Broker 1","x":"1","y":"3","width":"4","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$online_partitions1'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_11" >>$data_file
json_tab_12='{"type":"item","name":"Online Partitions Broker 2","x":"1","y":"5","width":"4","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$online_partitions2'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_12" >>$data_file
json_tab_13='{"type":"item","name":"Online Partitions Broker 3","x":"1","y":"7","width":"4","height":"2","view_mode":"0","fields":[{"type":"4","name":"itemid","value":"'$online_partitions3'"},{"type":"0","name":"show","value":"2"},{"type":"0","name":"show","value":"4"}]},'
echo -n "$json_tab_13" >>$data_file

#################Graphs
placey=0
place=1
IFS=";"
for type in ${items_per_topic_list}; do
    aggregate_function=""
    if [ $type = "Consumer Lag Metrics - MaxOffsetLag" ] || [ $type = "Consumer Lag Metrics - OffsetLag" ] || [ $type = "Consumer Lag Metrics - EstimatedMaxTimeLag" ]; then
        aggregate_function=3
    else
        aggregate_function=5
    fi
    placey=$((place * 4 + 5))

    json_part2='{"type": "svggraph","name": "'$type'","x": "1","y": "'$placey'","width": "11","height": "4","view_mode": "0","fields": [{"type": "0","name": "legend","value": "0"},'
    echo -n "$json_part2" >>$data_file
    pattern=$(echo $type | awk -F 'Per Topic' '{print $1;}')
    iteration=0

    unset IFS
    for i in $(echo $unique_topics); do
        #color=$(printf "%02x%02x%02x\n" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))) #- not working in zabbix
        color=$(echo "$(openssl rand -hex 3)")
        json_part3='{"type": "1","name": "ds.hosts.'$iteration'.0","value": "'${cluster}'"},{"type": "1","name": "ds.items.'$iteration'.0","value": "'$pattern*$i'"},{"type": "1","name": "ds.color.'$iteration'","value": "'$color'"},{"type": "0","name": "righty","value": "0"},{"type": "0","name": "ds.transparency.'$iteration'","value": "1"},{"type": "0","name": "ds.fill.'$iteration'","value": "1"},{"type": "0","name": "ds.aggregate_function.'$iteration'","value": "0"},{"type": "0","name": "ds.aggregate_grouping.'$iteration'","value": "0"},'
        echo -n "$json_part3" >>$data_file
        iteration=$(expr $iteration + 1)
    done
    truncate -s -1 $data_file
    json_part4=']},'
    echo -n "$json_part4" >>$data_file

    place=$(expr $place + 1)
    IFS=";"
done

json_listener1='{"type":"svggraph","name":"Connections Close rate per listener","x":"1","y":"49","width":"11","height":"4","view_mode":"0","fields":[{"type":"1","name":"ds.hosts.0.0","value":"'$host1'"},{"type":"1","name":"ds.items.0.0","value":"Connections close rate per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.0.1","value":"Connections Close rate per CLIENT_IAM"},{"type":"1","name":"ds.items.0.2","value":"Connections Close rate per REPLICATION"},{"type":"1","name":"ds.items.0.3","value":"Connections Close rate per REPLICATION_SECURE"},{"type":"1","name":"ds.color.0","value":"34BF37"},{"type":"0","name":"ds.transparency.0","value":"1"},{"type":"0","name":"ds.fill.0","value":"1"},{"type":"0","name":"righty","value":"0"},{"type":"1","name":"ds.hosts.1.0","value":"'$host2'"},{"type":"1","name":"ds.items.1.0","value":"Connections Close rate per CLIENT_IAM"},{"type":"1","name":"ds.items.1.1","value":"Connections Close rate per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.1.2","value":"Connections Close rate per REPLICATION"},{"type":"0","name":"legend_lines","value":"3"},{"type":"1","name":"ds.items.1.3","value":"Connections Close rate per REPLICATION_SECURE"},{"type":"1","name":"ds.color.1","value":"FF465C"},{"type":"0","name":"ds.transparency.1","value":"1"},{"type":"0","name":"ds.fill.1","value":"1"},{"type":"1","name":"ds.hosts.2.0","value":"'$host3'"},{"type":"1","name":"ds.items.2.0","value":"Connections Close rate per CLIENT_IAM"},{"type":"1","name":"ds.items.2.1","value":"Connections Close rate per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.2.2","value":"Connections Close rate per REPLICATION"},{"type":"1","name":"ds.items.2.3","value":"Connections Close rate per REPLICATION_SECURE"},{"type":"1","name":"ds.color.2","value":"0080FF"},{"type":"0","name":"ds.transparency.2","value":"1"},{"type":"0","name":"ds.fill.2","value":"1"}]},'
echo -n "$json_listener1" >>$data_file

json_listener2='{"type":"svggraph","name":"Connections count per listener","x":"1","y":"53","width":"11","height":"4","view_mode":"0","fields":[{"type":"1","name":"ds.hosts.0.0","value":"'$host1'"},{"type":"1","name":"ds.items.0.0","value":"Connections count per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.0.1","value":"Connections count per CLIENT_IAM"},{"type":"1","name":"ds.items.0.2","value":"Connections count per REPLICATION"},{"type":"1","name":"ds.items.0.3","value":"Connections count per REPLICATION_SECURE"},{"type":"1","name":"ds.color.0","value":"34BF37"},{"type":"0","name":"ds.transparency.0","value":"1"},{"type":"0","name":"ds.fill.0","value":"1"},{"type":"0","name":"righty","value":"0"},{"type":"1","name":"ds.hosts.1.0","value":"'$host2'"},{"type":"1","name":"ds.items.1.0","value":"Connections count per CLIENT_IAM"},{"type":"1","name":"ds.items.1.1","value":"Connections count per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.1.2","value":"Connections count per REPLICATION"},{"type":"0","name":"legend_lines","value":"3"},{"type":"1","name":"ds.items.1.3","value":"Connections count per REPLICATION_SECURE"},{"type":"1","name":"ds.color.1","value":"FF465C"},{"type":"0","name":"ds.transparency.1","value":"1"},{"type":"0","name":"ds.fill.1","value":"1"},{"type":"1","name":"ds.hosts.2.0","value":"'$host3'"},{"type":"1","name":"ds.items.2.0","value":"Connections count per CLIENT_IAM"},{"type":"1","name":"ds.items.2.1","value":"Connections count per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.2.2","value":"Connections count per REPLICATION"},{"type":"1","name":"ds.items.2.3","value":"Connections count per REPLICATION_SECURE"},{"type":"1","name":"ds.color.2","value":"0080FF"},{"type":"0","name":"ds.transparency.2","value":"1"},{"type":"0","name":"ds.fill.2","value":"1"}]},'
echo -n "$json_listener2" >>$data_file

json_listener3='{"type":"svggraph","name":"Connections creation rate per listener","x":"1","y":"57","width":"11","height":"4","view_mode":"0","fields":[{"type":"1","name":"ds.hosts.0.0","value":"'$host1'"},{"type":"1","name":"ds.items.0.0","value":"Connections creation rate per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.0.1","value":"Connections creation rate per CLIENT_IAM"},{"type":"1","name":"ds.items.0.2","value":"Connections creation rate per REPLICATION"},{"type":"1","name":"ds.items.0.3","value":"Connections creation rate per REPLICATION_SECURE"},{"type":"1","name":"ds.color.0","value":"34BF37"},{"type":"0","name":"ds.transparency.0","value":"1"},{"type":"0","name":"ds.fill.0","value":"1"},{"type":"0","name":"righty","value":"0"},{"type":"1","name":"ds.hosts.1.0","value":"'$host2'"},{"type":"1","name":"ds.items.1.0","value":"Connections creation rate per CLIENT_IAM"},{"type":"1","name":"ds.items.1.1","value":"Connections creation rate per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.1.2","value":"Connections creation rate per REPLICATION"},{"type":"0","name":"legend_lines","value":"3"},{"type":"1","name":"ds.items.1.3","value":"Connections creation rate per REPLICATION_SECURE"},{"type":"1","name":"ds.color.1","value":"FF465C"},{"type":"0","name":"ds.transparency.1","value":"1"},{"type":"0","name":"ds.fill.1","value":"1"},{"type":"1","name":"ds.hosts.2.0","value":"'$host3'"},{"type":"1","name":"ds.items.2.0","value":"Connections creation rate per CLIENT_IAM"},{"type":"1","name":"ds.items.2.1","value":"Connections creation rate per CLIENT_SASL_SCRAM"},{"type":"1","name":"ds.items.2.2","value":"Connections creation rate per REPLICATION"},{"type":"1","name":"ds.items.2.3","value":"Connections creation rate per REPLICATION_SECURE"},{"type":"1","name":"ds.color.2","value":"0080FF"},{"type":"0","name":"ds.transparency.2","value":"1"},{"type":"0","name":"ds.fill.2","value":"1"}]},'
echo -n "$json_listener3" >>$data_file

placey=0
place=1
IFS=";"
for type in ${items_per_broker_list}; do

    placey=$((place * 4 + 5))
    json_part6='{"type":"svggraph","name":"'$type'","x":"12","y":"'$placey'","width":"11","height":"4","view_mode":"0","fields":[{"type":"1","name":"ds.hosts.0.0","value":"'$host1'"},{"type":"1","name":"ds.items.0.0","value":"'$type'"},{"type":"1","name":"ds.color.0","value":"FF465C"},{"type":"1","name":"ds.hosts.1.0","value":"'$host2'"},{"type":"1","name":"ds.items.1.0","value":"'$type'"},{"type":"1","name":"ds.color.1","value":"FFFF00"},{"type":"1","name":"ds.hosts.2.0","value":"'$host3'"},{"type":"1","name":"ds.items.2.0","value":"'$type'"},{"type":"1","name":"ds.color.2","value":"0040FF"},{"type":"0","name":"righty","value":"0"}]},'
    echo -n "$json_part6" >>$data_file

    iteration=0

    place=$(expr $place + 1)

done
truncate -s -1 $data_file
json_final=']}]},"auth":"'$auth'","id":1}'
echo -n "$json_final" >>$data_file

curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"

rm $data_file

get_cluster_id=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "host.get","params": {"filter": {"host": ["'$cluster'"]}},"auth": "'$auth'","id": 1}' "$zabbix_url")
cluster_id=$(echo $get_cluster_id | grep -o '"hostid":"[^"]*' | grep -Eo '[0-9]{1,10}')

#trigger id
get_trigger_id=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "trigger.get","params": {"hostids": "'$cluster_id'","output": ["triggerid","description"]},"auth": "'$auth'","id": 1}' "$zabbix_url")
trigger_id=$(echo $get_trigger_id | awk -F 'Lld_execution_trigger' '{print $1;}' | grep -o '"triggerid":"[^"]*' | grep -Eo '[0-9]{1,10}')

#even ID
get_event_id=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "problem.get","params": {"output": ["eventid"],"objectids": "'$trigger_id'","sortfield": ["eventid"],"sortorder": "DESC"},"auth": "'$auth'","id": 1}' "$zabbix_url")
event_id=$(echo $get_event_id | grep -o '"eventid":"[^"]*' | grep -Eo '[0-9]{1,10}')

#acknowledge
curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "event.acknowledge","params": {"eventids": "'$event_id'","action": 1,"message": "Dashboard Recreated, aknowledging event"},"auth":"'$auth'","id": 1}' "$zabbix_url"
