#!/bin/bash/
auth="d6165047b19c9421729ea50b34a389f676338173d50960aa829cd6db7899a07c"
#zabbix_url="{$ZABBIX_URL}"
zbx_host="operations.ops.ped.local"
zabbix_url="https://${zbx_host}/api_jsonrpc.php"
echo $zabbix_url
Dash_name="WPTT"
existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "output": ["name", "dashboardid"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
# existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": {"output": "extend", "selectPages": "extend", "selectUsers": "extend", "selectUserGroups": "extend", "dashboardids": ["226"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
data_file="/tmp/zabbix_dash.json"


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
svggraph_type_list="Threading: Thread Count;Threading: Daemon thread count;Memory: Heap memory maximum size;Memory: Heap memory used;Memory: Non-Heap memory used;Memory: Heap memory committed;Memory: Non-Heap memory committed;Threading: Total started thread count;Threading: Peak thread count;OperatingSystem: File descriptors opened;OperatingSystem: Process CPU Load"
pattern="eu-we1-*.ppe.wpt.local"
##################################### Json Part2 ######################################################
top_host_type_list=
place=0
x=0
y=0

IFS=";"
for type in ${svggraph_type_list}
do
    # Calculate x and y positions
    if (( place % 2 == 0 )); then
        x=0
        y=$(( (place / 2) * 6 ))
    else
        x=12 # Assuming the width of each graph is 12
    fi
    color=$(printf "%02x%02x%02x\n" $((RANDOM%128)) $((RANDOM%128)) $((RANDOM%128)))
    # color=$(echo "$(openssl rand -hex 3)")
    json_part2='{"type":"svggraph","name":"'$type'","x":"'$x'","y":"'$y'","width":"12","height":"6","view_mode":"0","fields":[{"type":"0","name":"ds.transparency.0","value":"1"},{"type":"0","name":"ds.fill.0","value":"2"},{"type":"0","name":"righty","value":"0"},{"type":"1","name":"ds.hosts.0.0","value":"'$pattern'"},{"type":"1","name":"ds.items.0.0","value":"'$type'"},{"type":"0","name":"ds.type.0","value":"2"},{"type":"0","name":"ds.width.0","value":"4"},{"type":"1","name":"ds.color.0","value":"'$color'"}]},'
    echo -n "$json_part2" >> $data_file

    # Increment place for the next widget's position
    place=$((place + 1))
done
##################################### Json Final ######################################################
truncate -s -1 $data_file
json_final=']}]},"auth":"'$auth'","id":1}'
echo -n "$json_final" >> $data_file
curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"


