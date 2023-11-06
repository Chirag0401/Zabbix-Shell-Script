#!/bin/bash
#
#############
# operations.ops.ped.local   - Global for all core
# 172.141.19.48              - Endpoint for BCS OMS DMZ
# vpce-0ccd19187988b4975-d6iwetje.vpce-svc-0146fd1591f743767.eu-west-1.vpce.amazonaws.com  - Endpoint for WPT PPE1
#### Changes History
## Script Version: 0.1
zbx_host="{$ZABBIX_HOST}"
auth="{$ZABBIX_AUTH}"
#zabbix_url="https://${zbx_host}/api_jsonrpc.php"
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
if [[ $REGION = *"eu-west"* ]]; then
    RegionPattern="we1"
elif [[ $REGION = *"eu-central"* ]]; then
    RegionPattern="ce1"
else
    RegionPattern="Error"
fi
ZabbixAPIEndpointDMZ="zabbix-server-api-d-$RegionPattern.$envDomain"
ZabbixServers_EndpointsList="${zbx_host} $ZabbixAPIEndpointDMZ"
for x in $ZabbixServers_EndpointsList; do
    if (curl --connect-timeout 10 -I -k -s https://$x/ | egrep "200|200 OK" >/dev/null); then
        echo "Use it to reach Zabbix:  $x"
        zabbix_url="https://$x/api_jsonrpc.php"
        break
    else
        echo "Not Reachable $x"
    fi
done
######################
#zabbix_url="{$ZABBIX_URL}"
if test -f /etc/zabbix/zabbix_agentd.conf; then AgentFile=/etc/zabbix/zabbix_agentd.conf; else AgentFile=/etc/zabbix/zabbix_agent2.conf; fi
vm=$(grep ^Hostname= $AgentFile | awk -F= '{print $2}')
version=$(echo $vm | cut -d "." -f2)
Dash_name="Temporary-test"
### This variable can be hold multple groups seprated by space which will be having default access on all dashboards.
Dash_default_Sharing_Group=("p-ped-zabbix-nprod-admins")
TopHostsCount=100
existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "output": ["name", "dashboardid"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
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
    echo "Requeted Group Ids:  ${GROUP_IDS[@]} for dash access"
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
    ##  "userGroups":  '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"' ###
}
if [[ $vm = *"develop"* ]]; then
    version=$(echo $vm | cut -d "." -f2)
    Dash_name="BCS Sales Develop"
    Dash_Sharing_Group=("p-ped-zabbix-nprod-developer")
    host_group="Development-Kafka-Hosts"
    TopHostsCount=10
    data_file="/tmp/zabbix_dash.json"
    get_host_group=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "hostgroup.get","params": {"output": ["groupid"], "filter": {"name": ["'$host_group'"]}}, "auth": "'$auth'", "id": 1}' "$zabbix_url")
    group_id=$(echo $get_host_group | grep -o '"groupid":"[^"]*"' | cut -d ":" -f2 | tr -d '"')
    get_hosts=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "host.get","params": {"output": ["tags"], "groupids": ["'$group_id'"], "selectTags": "extend","evaltype": 0,"tags": [{"tag": "env","value": "e","operator": 0}]},"auth": "'$auth'","id": 1}' "$zabbix_url")
    existing_tags=$(echo $get_hosts | grep -o '"value":"[^"]*"' | sed 's/\"value\"://' | tr -d '"' | sort -u | awk -F'e' '{print $2}' | sort -n)
    echo "existing tags" $existing_tags
    if [[ $existing_dash = *$Dash_name* ]]; then
        echo "The existing dashboards are:" $existing_dash
        dash_id=$(echo $existing_dash | grep -o "{[^}]*$Dash_name*" | cut -d ":" -f2 | grep -Eo '[0-9]{1,6}')
        echo dash id is $dash_id
        dash_info=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "dashboardids": ["'$dash_id'"], "selectPages": "extend", "output": "extend"},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
        page_id=$(echo $dash_info | grep -o '"dashboard_pageid":"[^"]*' | cut -d ":" -f2 | tr -d '"')
        echo "Page id is " $page_id
        Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_default_Sharing_Group[@]}" "${Dash_Sharing_Group[@]}"
        json_part1='{"jsonrpc": "2.0","method": "dashboard.update","params": {"dashboardid": "'$dash_id'","userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"', "pages": [{"dashboard_pageid": "'$page_id'","widgets": ['
        echo -n "$json_part1" >>$data_file
    else
        echo "existing tags" $existing_tags
        Get_Dash_CurrentNRequested_Sharing na "${Dash_default_Sharing_Group[@]}" "${Dash_Sharing_Group[@]}"
        json_part1='{"jsonrpc":"2.0","method":"dashboard.create","params":{"name":"'$Dash_name'","userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"',"userid":"1","private":"1","display_period":10,"auto_start":1,"pages":[{"widgets":['
        echo -n "$json_part1" >>$data_file
    fi
    json_part2=""
    placex=0
    placey=0
    place=1
    for i in $(echo $existing_tags); do
        echo "Now running on" $i
        xpoz=$(expr $place % 2)
        if [[ "$xpoz" -eq 0 ]]; then
            placex=12
            placey=$((place * 3 - 6))
        else
            placex=0
            placey=$((place * 3 - 3))
        fi
        echo "The placex for it is " $placex
        echo "The placey for it is " $placey
        echo "Adding Dashboard Widget for dev " $i
        json_part2='{"type":"tophosts","name":"e'${i}'","x":"'$placex'","y":"'$placey'","width":"12","height":"6","view_mode":"0","fields":[{"type": "1","name": "columns.name.6","value": "Schema Registry / Kpow"},{"type": "0","name": "columns.data.6","value": "1"},{"type": "1","name": "columns.item.6","value": "Apache: Service ping"},{ "type": "1","name": "columns.timeshift.6","value": ""},{"type": "0","name": "columns.aggregate_function.6","value": "0"},{"type": "0","name": "columns.display.6","value": "1"},{"type": "0","name": "columns.history.6","value": "1"},{"type": "1","name": "columns.base_color.6","value": ""},{"type": "1","name": "columnsthresholds.color.6.0","value": "FF465C"},{"type": "1","name": "columnsthresholds.threshold.6.0","value": "0"},{"type": "1","name": "columnsthresholds.color.6.1","value": "80FF00"},{"type": "1","name": "columnsthresholds.threshold.6.1","value": "1"},{"type": "1","name": "columns.name.5","value": "Kafka"},{"type": "0","name": "columns.data.5","value": "1"},{"type": "1","name": "columns.item.5","value": "Kafka: Controller state on broker"},{"type": "1","name": "columns.timeshift.5","value": ""},{"type": "0","name": "columns.aggregate_function.5","value": "0"},{"type": "0","name": "columns.display.5","value": "1"},{"type": "0","name": "columns.history.5","value": "1"},{"type": "1","name": "columns.base_color.5","value": ""},{"type": "1","name": "columnsthresholds.color.5.0","value": "a7e1ec"},{"type": "1","name": "columnsthresholds.threshold.5.0","value": "0"},{"type": "1","name": "columnsthresholds.color.5.1","value": "80FF00"},{"type": "1","name": "columnsthresholds.threshold.5.1","value": "1"},{"type":"1","name":"columns.name.4","value":"Agent"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"Zabbix agent availability"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"1","name":"columnsthresholds.color.4.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"0","name":"column","value":"1"},{"type":"0","name":"count","value":"'$TopHostsCount'"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columnsthresholds.color.2.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"env"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"e'${i}'"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF4000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"}]},'
        echo -n "$json_part2" >>$data_file
        place=$(expr $place + 1)
        echo place is $place
    done
    placey=$((place * 3))
    #truncate -s -1 $data_file
    json_gkop='{"type":"tophosts","name":"GKOP-BCS-Dev","x":"0","y":"'$placey'","width":"24","height":"3","view_mode":"0","fields":[{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"1","name":"columnsthresholds.color.3.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"85"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.1","value":"CPU (system_runtime_cpu_usage)"},{"type":"1","name":"columns.name.2","value":"CPU (process_cpu_seconds_total)"},{"type":"1","name":"columns.item.2","value":"process_cpu_seconds_total"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"1","name":"columns.min.4","value":"0"},{"type":"1","name":"columns.max.4","value":"100"},{"type":"0","name":"columns.display.4","value":"3"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"85"},{"type":"1","name":"columnsthresholds.color.4.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.2","value":"95"},{"type":"1","name":"columns.name.5","value":"process_open_handles"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.item.5","value":"process_open_handles"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"1","name":"tags.tag.0","value":"platform"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"gkop"},{"type":"1","name":"columns.name.3","value":"Mem (dotnet_total_memory_bytes)"},{"type":"1","name":"columns.item.3","value":"dotnet_total_memory"},{"type":"1","name":"columnsthresholds.color.3.0","value":"00FF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"50"},{"type":"1","name":"columns.name.4","value":"Mem (process_private_memory)"},{"type":"1","name":"columns.item.4","value":"process_private_memory"},{"type":"1","name":"columnsthresholds.color.4.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"0","name":"columns.data.2","value":"1"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"0","name":"column","value":"1"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columns.name.0","value":"name"},{"type":"1","name":"columns.item.1","value":"cpu_usage"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columns.base_color.2","value":""}]}'
    echo -n "$json_gkop" >>$data_file
    json_part3=']}]},"auth":"'$auth'","id":1}'
    echo -n "$json_part3" >>$data_file
    curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"
    rm $data_file
else
    ENV=""
    Dash_name=""
    host_group=""
    if [[ $vm = *"ppe"* ]] && [[ $vm != *"ppe.wpt"* ]]; then
        ENV="ppe"
        Dash_name="BCS Sales PPE"
        host_group="ppe.bcs-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly")
        cluster="cluster.msk-ppe"
    elif [[ $vm = *"ppe.wpt"* ]]; then
        ENV="ppe"
        Dash_name="WPT PPE"
        host_group="ppe.wpt-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-nprod-admins")
    elif [[ $vm = *"sit"* ]]; then
        ENV="sit"
        Dash_name="BCS Sales SIT"
        host_group="sit.bcs-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly")
        cluster="cluster.msk-sit"
    elif [[ $vm = *"ped"* ]]; then
        ENV="ppe"
        Dash_name="PED PPE"
        host_group="ops.ped-servers"
        Dash_Sharing_Group=("p-ped-zabbix-nprod-admins")
    elif [[ $vm = *"patch.bcs"* ]]; then
        ENV="patching"
        Dash_name="BCS Sales Patching"
        host_group="patch.bcs-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-nprod-ops" "p-ped-zabbix-nprod-ops-readonly")
    elif [[ $vm = *"ppe.shp"* ]]; then
        ENV="ppe"
        Dash_name="Shoppify PPE"
        host_group="ppe.shp-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-nprod-admins")
    ############ PROD ENV #######
    elif [[ $vm = *"muat.wpt"* ]]; then
        ENV="muat"
        Dash_name="WPT MUAT"
        host_group="muat.wpt-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-prod-ops" "p-ped-zabbix-prod-ops-readonly" "p-ped-zabbix-prod-admins")
    elif [[ $vm = *"prod.ops"* ]]; then
        ENV="prod"
        Dash_name="PED PROD"
        host_group="prod.ops-Servers"
        Dash_Sharing_Group=("p-ped-zabbix-prod-ops" "p-ped-zabbix-prod-ops-readonly" "p-ped-zabbix-prod-admins")
    elif [[ $vm = *"prod.bcs"* ]]; then
        ENV="prod"
        Dash_name="BCS Sales PROD"
        host_group="prod.bcs-Servers"
        cluster="cluster.msk-prod"
        Dash_Sharing_Group=("p-ped-zabbix-prod-ops" "p-ped-zabbix-prod-ops-readonly" "p-ped-zabbix-prod-admins")
    fi
    data_file="/tmp/zabbix_'$ENV'_dash.json"
    echo "The existing dashboards are:" $existing_dash
    get_host_group=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "hostgroup.get","params": {"output": ["groupid"], "filter": {"name": ["'$host_group'"]}}, "auth": "'$auth'", "id": 1}' "$zabbix_url")
    group_id=$(echo $get_host_group | grep -o '"groupid":"[^"]*"' | cut -d ":" -f2 | tr -d '"')
    get_hosts=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0","method": "host.get","params": {"output": ["tags"], "groupids": ["'$group_id'"], "selectTags": "extend","evaltype": 0,"tags": [{"tag": "env","value": "'$ENV'","operator": 0}]},"auth": "'$auth'","id": 1}' "$zabbix_url")
    REGION=$(echo $get_hosts | grep -o '"region","value":"[^"]*"' | sed 's/\"region\",\"value\"://' | tr -d '"' | sort -u)
    echo "existing regions" $REGION
    project=$(echo $get_hosts | grep -o '"project","value":"[^"]*"' | sed 's/\"project\",\"value\"://' | tr -d '"' | sort -u)
    echo "Projects are: " $project
    if [[ $existing_dash = *$Dash_name* ]]; then
        dash_id=$(echo $existing_dash | grep -o "{[^}]*$Dash_name*" | cut -d ":" -f2 | grep -Eo '[0-9]{1,6}')
        echo dash id is $dash_id
        Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_default_Sharing_Group[@]}" "${Dash_Sharing_Group[@]}"
        dash_info=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "dashboardids": ["'$dash_id'"], "selectPages": "extend", "output": "extend"},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
        page_id=$(echo $dash_info | grep -o '"dashboard_pageid":"[^"]*' | cut -d ":" -f2 | tr -d '"')
        echo "Page id is " $page_id
        json_part1='{"jsonrpc": "2.0","method": "dashboard.update","params": {"dashboardid": "'$dash_id'", "userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"',"pages": [{"dashboard_pageid": "'$page_id'","widgets": ['
        echo -n "$json_part1" >>$data_file
    else
        Get_Dash_CurrentNRequested_Sharing na "${Dash_default_Sharing_Group[@]}" "${Dash_Sharing_Group[@]}"
        json_part1='{"jsonrpc":"2.0","method":"dashboard.create","params":{"name":"'$Dash_name'","userGroups": '"${Get_Dash_CurrentNRequested_Sharing_JOUT}"',"userid":"1","private":"1","display_period":10,"auto_start":1,"pages":[{"widgets":['
        echo -n "$json_part1" >>$data_file
    fi
    json_part2=""
    placex=0
    placey=0
    place=1
    for j in $(echo $project); do
        for i in $(echo $REGION); do
            if [[ $j == "wpt" ]]; then
                for netgroup in CORE DMZ; do
                    echo "Now running on $i for $j"
                    xpoz=$(expr $place % 2)
                    if [[ "$xpoz" -eq 0 ]]; then
                        placex=11
                        placey=$((place * 4 - 8))
                    else
                        placex=0
                        placey=$((place * 4 - 4))
                    fi
                    echo place is $place
                    echo "The placex for it is " $placex
                    echo "The placey for it is " $placey
                    echo "Adding Dashboard Widget for " $j $i $netgroup
                    #json_part2='{"type":"tophosts","name":"'$ENV'-'$j'-'$i'-'$netgroup'","x":"'$placex'","y":"'$placey'","width":"11","height":"8","view_mode":"0","fields":[{"type":"0","name":"count","value":"99"},{"type": "1","name": "columns.name.5","value": "JBOSS Status"},{"type": "0","name": "columns.data.5","value": "1"},{"type": "1","name": "columns.item.5","value": "Apache: Service ping"},{ "type": "1","name": "columns.timeshift.5","value": ""},{"type": "0","name": "columns.aggregate_function.5","value": "0"},{"type": "0","name": "columns.display.5","value": "1"},{"type": "0","name": "columns.history.5","value": "1"},{"type": "1","name": "columns.base_color.5","value": ""},{"type": "1","name": "columnsthresholds.color.5.0","value": "FF465C"},{"type": "1","name": "columnsthresholds.threshold.5.0","value": "0"},{"type": "1","name": "columnsthresholds.color.5.1","value": "80FF00"},{"type": "1","name": "columnsthresholds.threshold.5.1","value": "1"},{"type":"1","name":"columns.name.4","value":"Agent"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"Zabbix agent availability"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"1","name":"columnsthresholds.color.4.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"0","name":"column","value":"1"},{"type":"0","name":"count","value":"20"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columnsthresholds.color.2.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"env"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$ENV'"},{"type":"1","name":"tags.tag.1","value":"region"},{"type":"0","name":"tags.operator.1","value":"1"},{"type":"1","name":"tags.value.1","value":"'$i'"},{"type":"1","name":"tags.tag.2","value":"project"},{"type":"0","name":"tags.operator.2","value":"1"},{"type":"1","name":"tags.value.2","value":"'$j'"},{"type":"1","name":"tags.tag.3","value":"NetworkGroup"},{"type":"0","name":"tags.operator.3","value":"1"},{"type":"1","name":"tags.value.3","value":"'$netgroup'"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF4000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"}]},'
                    json_part2='{"type":"tophosts","name":"'$ENV'-'$j'-'$i'-'$netgroup'","x":"'$placex'","y":"'$placey'","width":"11","height":"8","view_mode":"0","fields":[{"type":"0","name":"count","value":"'$TopHostsCount'"},{"type":"1","name":"columns.name.5","value":"JBOSS Status"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.item.5","value":"Apache: Service ping"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"1","name":"columnsthresholds.color.5.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.5.0","value":"0"},{"type":"1","name":"columnsthresholds.color.5.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.5.1","value":"1"},{"type":"1","name":"columns.name.4","value":"Agent"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"Zabbix agent availability"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"1","name":"columnsthresholds.color.4.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"0","name":"column","value":"1"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columnsthresholds.color.2.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"env"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$ENV'"},{"type":"1","name":"tags.tag.1","value":"region"},{"type":"0","name":"tags.operator.1","value":"1"},{"type":"1","name":"tags.value.1","value":"'$i'"},{"type":"1","name":"tags.tag.2","value":"project"},{"type":"0","name":"tags.operator.2","value":"1"},{"type":"1","name":"tags.value.2","value":"'$j'"},{"type":"1","name":"tags.tag.3","value":"NetworkGroup"},{"type":"0","name":"tags.operator.3","value":"1"},{"type":"1","name":"tags.value.3","value":"'$netgroup'"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF4000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"}]},'
                    echo -n "$json_part2" >>$data_file
                    place=$(expr $place + 1)
                done
            else
                echo "Now running on $i for $j"
                xpoz=$(expr $place % 2)
                if [[ "$xpoz" -eq 0 ]]; then
                    placex=11
                    placey=$((place * 4 - 8))
                else
                    placex=0
                    placey=$((place * 4 - 4))
                fi
                echo place is $place
                echo "The placex for it is " $placex
                echo "The placey for it is " $placey
                echo "Adding Dashboard Widget for " $j $i
                #json_part2='{"type":"tophosts","name":"'$ENV'-'$j'","x":"'$placex'","y":"'$placey'","width":"11","height":"8","view_mode":"0","fields":[{"type":"0","name":"count","value":"49"},{"type":"1","name":"columns.name.4","value":"Agent"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"Zabbix agent availability"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"1","name":"columnsthresholds.color.4.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"0","name":"column","value":"1"},{"type":"0","name":"count","value":"20"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columnsthresholds.color.2.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"env"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$ENV'"},{"type":"1","name":"tags.tag.1","value":"region"},{"type":"0","name":"tags.operator.1","value":"1"},{"type":"1","name":"tags.value.1","value":"'$i'"},{"type":"1","name":"tags.tag.2","value":"project"},{"type":"0","name":"tags.operator.2","value":"1"},{"type":"1","name":"tags.value.2","value":"'$j'"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF4000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"}]},'
                json_part2='{"type":"tophosts","name":"'$ENV'-'$j'","x":"'$placex'","y":"'$placey'","width":"11","height":"8","view_mode":"0","fields":[{"type":"0","name":"count","value":"'$TopHostsCount'"},{"type":"1","name":"columns.name.5","value":"Schema Registry"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.item.5","value":"Apache: Service ping"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"1","name":"columnsthresholds.color.5.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.5.0","value":"0"},{"type":"1","name":"columnsthresholds.color.5.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.5.1","value":"1"},{"type":"1","name":"columns.name.4","value":"Agent"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"Zabbix agent availability"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"1","name":"columnsthresholds.color.4.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"0","name":"column","value":"1"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columnsthresholds.color.2.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"env"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$ENV'"},{"type":"1","name":"tags.tag.1","value":"region"},{"type":"0","name":"tags.operator.1","value":"1"},{"type":"1","name":"tags.value.1","value":"'$i'"},{"type":"1","name":"tags.tag.2","value":"project"},{"type":"0","name":"tags.operator.2","value":"1"},{"type":"1","name":"tags.value.2","value":"'$j'"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF4000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"}]},'
                echo -n "$json_part2" >>$data_file
                place=$(expr $place + 1)
            fi
        done
    done
    xpoz=$(expr $place % 2)
    if [[ "$xpoz" -eq 0 ]]; then
        placex=11
        placey=$((place * 4 - 8))
    else
        placex=0
        placey=$((place * 4 - 4))
    fi
    if [ -z $cluster ]; then
        echo "Not creating MSK tophosts"
    elif [[ $ENV = "ppe" ]] || [[ $ENV = "prod" ]]; then
        echo "Adding Widget for MSK" $ENV
        xpoz=$(expr $place % 2)
        if [[ "$xpoz" -eq 0 ]]; then
            placex=11
            placey=$((place * 4 - 8))
        else
            placex=0
            placey=$((place * 4 - 4))
        fi
        for j in {1..2}; do
            json_msk='{"type":"tophosts","name":"'${ENV}${j}'-MSK","x":"'$placex'","y":"'$placey'","width":"11","height":"4","view_mode":"0","fields":[{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"Active Controller"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"Active Controller Count"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"1"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.base_color.1","value":""},{"type":"1","name":"columnsthresholds.color.1.0","value":"00FFFF"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"0"},{"type":"1","name":"columnsthresholds.color.1.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"1"},{"type":"0","name":"columns.data.2","value":"1"},{"type":"1","name":"columns.name.2","value":"CPU"},{"type":"1","name":"columns.item.2","value":"Cpu Usage"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columnsthresholds.color.2.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"90"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"1","name":"columns.item.3","value":"Filesystem utilisation percentage"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"1","name":"columns.base_color.3","value":"80FF00"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"msk"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'${ENV}${j}'"}]},'
            echo -n "$json_msk" >>$data_file
            placey=$(expr $placey + 4)
        done
        #truncate -s -1 $data_file
    else
        echo "Adding Default Widget for MSK" $ENV
        json_msk='{"type":"tophosts","name":"'$ENV'-MSK","x":"'$placex'","y":"'$placey'","width":"11","height":"4","view_mode":"0","fields":[{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"Active Controller"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"Active Controller Count"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"1"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.base_color.1","value":""},{"type":"1","name":"columnsthresholds.color.1.0","value":"00FFFF"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"0"},{"type":"1","name":"columnsthresholds.color.1.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"1"},{"type":"0","name":"columns.data.2","value":"1"},{"type":"1","name":"columns.name.2","value":"CPU"},{"type":"1","name":"columns.item.2","value":"Cpu Usage"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columnsthresholds.color.2.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"90"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"1","name":"columns.item.3","value":"Filesystem utilisation percentage"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"1","name":"columns.base_color.3","value":"80FF00"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"msk"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$ENV'"}]},'
        echo -n "$json_msk" >>$data_file
        ####### GKOP ####
        placey=$((place * 4))
        #truncate -s -1 $data_file
        json_gkop='{"type":"tophosts","name":"GKOP-BCS-Dev","x":"0","y":"'$placey'","width":"24","height":"3","view_mode":"0","fields":[{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"1","name":"columnsthresholds.color.3.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"85"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.1","value":"CPU (system_runtime_cpu_usage)"},{"type":"1","name":"columns.name.2","value":"CPU (process_cpu_seconds_total)"},{"type":"1","name":"columns.item.2","value":"process_cpu_seconds_total"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"1","name":"columns.min.4","value":"0"},{"type":"1","name":"columns.max.4","value":"100"},{"type":"0","name":"columns.display.4","value":"3"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"85"},{"type":"1","name":"columnsthresholds.color.4.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.2","value":"95"},{"type":"1","name":"columns.name.5","value":"process_open_handles"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.item.5","value":"process_open_handles"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"1","name":"tags.tag.0","value":"platform"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"gkop"},{"type":"1","name":"columns.name.3","value":"Mem (dotnet_total_memory_bytes)"},{"type":"1","name":"columns.item.3","value":"dotnet_total_memory"},{"type":"1","name":"columnsthresholds.color.3.0","value":"00FF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"50"},{"type":"1","name":"columns.name.4","value":"Mem (process_private_memory)"},{"type":"1","name":"columns.item.4","value":"process_private_memory"},{"type":"1","name":"columnsthresholds.color.4.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"0","name":"columns.data.2","value":"1"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"0","name":"column","value":"1"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columns.name.0","value":"name"},{"type":"1","name":"columns.item.1","value":"cpu_usage"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columns.base_color.2","value":""}]},'
        echo -n "$json_gkop" >>$data_file
    fi
    truncate -s -1 $data_file
    json_part3=']}]},"auth":"'$auth'","id":1}'
    echo -n "$json_part3" >>$data_file
    curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"
    rm $data_file
fi
