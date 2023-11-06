#!/bin/bash/
auth=""
#zabbix_url="{$ZABBIX_URL}"
zbx_host=""
zabbix_url="https://${zbx_host}/api_jsonrpc.php"
echo $zabbix_url
Dash_name="WPTT"
existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "output": ["name", "dashboardid"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
# existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": {"output": "extend", "selectPages": "extend", "selectUsers": "extend", "selectUserGroups": "extend", "dashboardids": ["226"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
data_file="/tmp/zabbix_dash.json"

# color=$(printf "%02x%02x%02x\n" $((RANDOM%128)) $((RANDOM%128)) $((RANDOM%128)))

##################################### Json Part1 ######################################################
case ${existing_dash} in
*"${Dash_name}"*)
echo "The existing dashboards are:" $existing_dash
dash_id=$(echo $existing_dash | grep -o "{[^}]*$Dash_name*" | cut -d ":" -f2 | grep -Eo '[0-9]{1,10}')
echo dash id is $dash_id

dash_info=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "dashboardids": ["'$dash_id'"], "selectPages": "extend", "output": "extend"},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
page_id=$( echo $dash_info | grep -o '"dashboard_pageid":"[^"]*' | cut -d ":" -f2 | tr -d '"')
echo "Page id is " $page_id

Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_Sharing_Group[@]}"
json_part1='{"jsonrpc": "2.0","method": "dashboard.update","params": {"dashboardid": "'$dash_id'","pages": [{"dashboard_pageid": "'$page_id'","widgets": ['
echo -n "$json_part1" >> $data_file

;;
*)
Get_Dash_CurrentNRequested_Sharing na "${Dash_Sharing_Group[@]}"
json_part1='{"jsonrpc":"2.0","method":"dashboard.create","params":{"name":"'$Dash_name'","userid":"1","private":"1","display_period":10,"auto_start":1,"pages":[{"widgets":['
echo -n "$json_part1" >> $data_file
;;
esac

##################################### Json Part2 ######################################################
svggraph_type_list="Threading: Thread Count;Threading: Daemon thread count;Memory: Heap memory maximum size"
pattern="eu-we1-*.ppe.wpt.local"
place=0
x_position=0
y_position=0

IFS=";"
for type in ${svggraph_type_list}
do
    # Calculate x and y positions
    if (( place % 2 == 0 )); then
        x_position=0
        y_position=$(( (place / 2) * 6 ))
    else
        x_position=12 # Assuming the width of each graph is 12
    fi

    json_part2='{"type":"svggraph","name":"'$type'","x":"'$x_position'","y":"'$y_position'","width":"12","height":"6","view_mode":"0","fields":[{"type":"0","name":"ds.transparency.0","value":"1"},{"type":"0","name":"ds.fill.0","value":"2"},{"type":"0","name":"righty","value":"0"},{"type":"1","name":"ds.hosts.0.0","value":"'$pattern'"},{"type":"1","name":"ds.items.0.0","value":"'$type'"},{"type":"0","name":"ds.type.0","value":"2"},{"type":"0","name":"ds.width.0","value":"4"},{"type":"1","name":"ds.color.0","value":"5E35B1"}]},'
    echo -n "$json_part2" >> $data_file

    # Increment place for the next widget's position
    place=$((place + 1))
done
##################################### Json Final ######################################################
truncate -s -1 $data_file
json_final=']}]},"auth":"'$auth'","id":1}'
echo -n "$json_final" >> $data_file
curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"


#{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params.","data":"Overlapping widgets at X:0, Y:9 on page #1 of dashboard \"WPTT\".","debug":[{"file":"/usr/share/zabbix/include/classes/api/services/CDashboardGeneral.php","line":337,"function":"exception","class":"CApiService","type":"::"},{"file":"/usr/share/zabbix/include/classes/api/services/CDashboard.php","line":270,"function":"checkWidgets","class":"CDashboardGeneral","type":"->"},{"file":"/usr/share/zabbix/include/classes/api/services/CDashboard.php","line":160,"function":"validateCreate","class":"CDashboard","type":"->"},{"file":"/usr/share/zabbix/include/classes/api/clients/CLocalApiClient.php","line":121,"function":"create","class":"CDashboard","type":"->"},{"file":"/usr/share/zabbix/include/classes/core/CJsonRpc.php","line":75,"function":"callMethod","class":"CLocalApiClient","type":"->"},{"file":"/usr/share/zabbix/api_jsonrpc.php","line":63,"function":"execute","class":"CJsonRpc","type":"->"}]},"id":1}
#{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params.","data":"Overlapping widgets at X:0, Y:13 on page #1 of dashboard \"WPTT\".","debug":[{"file":"/usr/share/zabbix/include/classes/api/services/CDashboardGeneral.php","line":337,"function":"exception","class":"CApiService","type":"::"},{"file":"/usr/share/zabbix/include/classes/api/services/CDashboard.php","line":270,"function":"checkWidgets","class":"CDashboardGeneral","type":"->"},{"file":"/usr/share/zabbix/include/classes/api/services/CDashboard.php","line":160,"function":"validateCreate","class":"CDashboard","type":"->"},{"file":"/usr/share/zabbix/include/classes/api/clients/CLocalApiClient.php","line":121,"function":"create","class":"CDashboard","type":"->"},{"file":"/usr/share/zabbix/include/classes/core/CJsonRpc.php","line":75,"function":"callMethod","class":"CLocalApiClient","type":"->"},{"file":"/usr/share/zabbix/api_jsonrpc.php","line":63,"function":"execute","class":"CJsonRpc","type":"->"}]},"id":1}
