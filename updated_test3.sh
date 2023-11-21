#!/bin/bash

# Script Variables
auth="d6165047b19c9421729ea50b34a389f676338173d50960aa829cd6db7899a07c"
zbx_host="operations.ops.ped.local"
zabbix_url="https://${zbx_host}/api_jsonrpc.php"
Dash_name="WPTT"
existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "output": ["name", "dashboardid"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
data_file="/tmp/zabbix_dash.json"

# Function Definitions
Get_Dash_CurrentNRequested_Sharing() { :; }
generate_dark_color() { printf "%02x%02x%02x\n" $((RANDOM%128+127)) $((RANDOM%128+127)) $((RANDOM%128+127)); }

# Check if the dashboard already exists and set the json_part1 accordingly
case ${existing_dash} in
  *"${Dash_name}"*)
    # Existing dashboard found, prepare to update
    dash_id=$(echo $existing_dash | grep -o "{[^}]*$Dash_name*" | cut -d ":" -f2 | grep -Eo '[0-9]{1,10}')
    dash_info=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "dashboardids": ["'$dash_id'"], "selectPages": "extend", "output": "extend"},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
    page_id=$(echo $dash_info | grep -o '"dashboard_pageid":"[^"]*' | cut -d ":" -f2 | tr -d '"')
    Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_Sharing_Group[@]}"
    json_part1='{"jsonrpc": "2.0","method": "dashboard.update","params": {"dashboardid": "'$dash_id'","pages": [{"dashboard_pageid": "'$page_id'","widgets": ['
    ;;
  *)
    # No existing dashboard found, prepare to create a new one
    Get_Dash_CurrentNRequested_Sharing na "${Dash_Sharing_Group[@]}"
    json_part1='{"jsonrpc":"2.0","method":"dashboard.create","params":{"name":"'$Dash_name'","userid":"1","private":"1","display_period":10,"auto_start":1,"pages":[{"widgets":['
    ;;
esac

# Start building the JSON payload
echo -n "$json_part1" > $data_file

# Variables for widget placement
top_widget_height=6
top_widget_width=24
graph_widget_height=6
graph_widget_width=12
dashboard_max_width=24  # Dashboard width
dashboard_max_height=62 # Dashboard height
x=0
y=0
i="eu-west-1"
j="wpt"
ENV="ppe"
TopHostsCount=100
network_groups=("CORE" "DMZ")

# Add top_hosts widgets
for netgroup in "${network_groups[@]}"; do
  # Check for widget placement constraints
  if (( x + top_widget_width > dashboard_max_width )); then
    x=0
    y=$((y + top_widget_height))
  fi
  if (( y + top_widget_height > dashboard_max_height)); then 
    echo "Error: Widget placement for 'top_hosts' exceeds dashboard height."
    exit 1
  fi

  # Define the JSON for top_hosts widget
  json_top_hosts_widget='{"type":"tophosts","name":"WPT Hosts-'$netgroup'","x":"'$x'","y":"'$y'","width":'$top_widget_width',"height":"'$top_widget_height'","view_mode":"0","fields":[{"type":"1","name":"tags.tag.0","value":"project"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"wpt"},{"type":"1","name":"tags.tag.3","value":"NetworkGroup"},{"type":"0","name":"tags.operator.3","value":"1"},{"type":"1","name":"tags.value.3","value":"'$netgroup'"},{"type":"0","name":"tags.operator.1","value":"1"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF0000"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"0","name":"columns.display.2","value":"2"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.base_color.2","value":"00FF00"},{"type":"1","name":"columnsthresholds.color.2.0","value":"00FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF4000"},{"type":"1","name":"tags.tag.2","value":"region"},{"type":"1","name":"columns.name.3","value":"Disk( \/ )"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"\/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"0","name":"tags.operator.2","value":"1"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"tags.value.2","value":"'$i'"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columns.name.4","value":"Disk( \/u02 )"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"\/u02: Space utilization"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"1","name":"columns.min.4","value":"0"},{"type":"1","name":"columns.max.4","value":"100"},{"type":"0","name":"columns.display.4","value":"2"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"80"},{"type":"1","name":"columnsthresholds.color.4.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"90"},{"type":"1","name":"columnsthresholds.color.4.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.2","value":"95"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"1","name":"columnsthresholds.color.5.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.5.0","value":"0"},{"type":"0","name":"columns.data.6","value":"1"},{"type":"1","name":"columns.timeshift.6","value":""},{"type":"0","name":"columns.aggregate_function.6","value":"0"},{"type":"0","name":"columns.display.6","value":"1"},{"type":"0","name":"columns.history.6","value":"1"},{"type":"1","name":"columns.base_color.6","value":""},{"type":"1","name":"columnsthresholds.color.7.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.7.0","value":"0"},{"type":"0","name":"column","value":"1"},{"type":"0","name":"count","value":"100"},{"type":"1","name":"columnsthresholds.color.3.3","value":"E64A19"},{"type":"1","name":"columnsthresholds.threshold.3.3","value":"95"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"90"},{"type":"0","name":"columns.display.3","value":"2"},{"type":"1","name":"columns.base_color.3","value":"00FF00"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFEE58"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"85"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF7043"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"90"},{"type":"1","name":"columnsthresholds.color.7.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.7.1","value":"1"},{"type":"1","name":"columns.name.7","value":"Agent"},{"type":"0","name":"columns.data.7","value":"1"},{"type":"1","name":"columns.item.7","value":"Zabbix agent availability"},{"type":"1","name":"columns.item.5","value":"Runtime: JVM uptime"},{"type":"1","name":"columns.name.6","value":"Service Status"},{"type":"1","name":"columns.timeshift.7","value":""},{"type":"0","name":"columns.aggregate_function.7","value":"0"},{"type":"0","name":"columns.display.7","value":"1"},{"type":"0","name":"columns.history.7","value":"1"},{"type":"1","name":"columns.base_color.7","value":""},{"type":"1","name":"columns.name.5","value":"JVM Uptime(H:MM)"},{"type":"1","name":"columnsthresholds.color.5.1","value":"BFFF00"},{"type":"1","name":"columnsthresholds.color.6.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.6.0","value":"0"},{"type":"1","name":"columnsthresholds.color.6.1","value":"00FF00"},{"type":"1","name":"columnsthresholds.threshold.6.1","value":"1"},{"type":"1","name":"tags.tag.1","value":"env"},{"type":"1","name":"tags.value.1","value":"'$ENV'"},{"type":"1","name":"columnsthresholds.color.5.2","value":"BFFF00"},{"type":"1","name":"columnsthresholds.threshold.5.2","value":"1"},{"type":"1","name":"columnsthresholds.threshold.5.1","value":"0.01"},{"type":"1","name":"columns.item.6","value":"Process Check"}]},'
  
  # Output for debugging
  echo "Placing widget at X:$x Y:$y with Width:$top_widget_width Height:$top_widget_height"

  # Append the widget JSON to the data file
  echo -n "$json_top_hosts_widget" >> $data_file

  # Update position for next widget
  x=$((x + top_widget_width))
  if (( x >= dashboard_max_width )); then
    x=0
    y=$((y + top_widget_height))
  fi
done

# Problems widget setup
if (( x + top_widget_width > dashboard_max_width )); then
  x=0
  y=$((y + top_widget_height))
fi

# Define JSON for problems widget
json_problem_widgets='{"type":"problems","name":"","x":"'$x'","y":"'$y'","width":"'$top_widget_width'","height":"'$top_widget_height'","view_mode":"0","fields":[{"type":"1","name":"tags.tag.2","value":"'$i'"},{"type":"0","name":"tags.operator.2","value":"0"},{"type":"1","name":"tags.value.2","value":"'$i'"},{"type":"2","name":"groupids","value":"36"},{"type":"0","name":"severities","value":"3"},{"type":"0","name":"severities","value":"5"},{"type":"1","name":"tags.tag.0","value":"project"},{"type":"0","name":"tags.operator.0","value":"0"},{"type":"1","name":"tags.value.0","value":"'$j'"},{"type":"1","name":"tags.tag.1","value":"env"},{"type":"0","name":"tags.operator.1","value":"0"},{"type":"1","name":"tags.value.1","value":"'$ENV'"}]},'
echo -n "$json_problem_widgets" >> $data_file

# Update Y position for next widget
x=0
y=$((y + 4))

# Ensure y is at the start of the next row if top_hosts widgets didn't exactly fill the last row
if (( y % graph_widget_height != 0 )); then
  y=$(( (y / graph_widget_height + 1) * graph_widget_height ))
fi

# Add svggraph widgets
svggraph_type_list=("Threading: Thread Count" "Threading: Daemon thread count" "Memory: Heap memory maximum size" "Memory: Heap memory used" "Memory: Non-Heap memory used" "Memory: Heap memory committed" "Memory: Non-Heap memory committed" "Threading: Total started thread count" "Threading: Peak thread count" "OperatingSystem: File descriptors opened" "OperatingSystem: Process CPU Load")
host_group=("eu-we1-ca01.ppe.bcs.local" "eu-ce1-c-mgt11.ppe.wpt.local" "eu-ce1-c-zrd11.ppe.wpt.local")

# Calculate the maximum number of widgets that can fit vertically
max_widgets_vertically=$((dashboard_max_height / graph_widget_height))

# Loop through each item type to create a widget
for type in "${svggraph_type_list[@]}"; do
  # Check if we need to start a new column
  if (( y / graph_widget_height >= max_widgets_vertically )); then
    x=$((x + graph_widget_width))
    y=0  # Reset y position for the new column
  fi

  # Check if we have space for a new column
  if (( x + graph_widget_width > dashboard_max_width )); then
    echo "Error: No more space for a new widget column."
    exit 1
  fi

  # Initialize the JSON for the svggraph widget
  json_svggraph_widget="{\"type\":\"svggraph\",\"name\":\"$type\",\"x\":$x,\"y\":$y,\"width\":$graph_widget_width,\"height\":$graph_widget_height,\"view_mode\":0,\"fields\":["

  # Loop through each host to create individual datasets for the current type
  for host in "${host_group[@]}"; do
    color=$(generate_dark_color)  # Generate a color for the dataset
    json_svggraph_widget+="{\"type\":\"1\",\"name\":\"ds.hosts.0.0\",\"value\":\"$host\"},{\"type\":\"1\",\"name\":\"ds.items.0.0\",\"value\":\"$type\"},{\"type\":\"0\",\"name\":\"ds.transparency.0\",\"value\":\"1\"},{\"type\":\"0\",\"name\":\"ds.fill.0\",\"value\":\"2\"},{\"type\":\"0\",\"name\":\"righty\",\"value\":\"0\"},{\"type\":\"0\",\"name\":\"ds.type.0\",\"value\":\"2\"},{\"type\":\"0\",\"name\":\"ds.width.0\",\"value\":\"4\"},{\"type\":\"1\",\"name\":\"ds.color.0\",\"value\":\"$color\"},"
  done

  # Remove the last comma and close the JSON object
  json_svggraph_widget="${json_svggraph_widget%,}]},"

  # Output the placement information for debugging
  echo "Placing widget at X:$x Y:$y with Width:$graph_widget_width Height:$graph_widget_height"

  # Append the widget JSON to the data file
  echo -n "$json_svggraph_widget" >> $data_file

  # Increment y for the next widget within the same column
  y=$((y + graph_widget_height))
done

# Finalize the JSON file
sed -i '$ s/,$//' $data_file  # Remove the last comma
echo -n ']}]},"auth":"'$auth'","id":1}' >> $data_file

# Validate and send the JSON to Zabbix
if ! jq empty $data_file; then
    echo "JSON is invalid. Please check the $data_file file for syntax errors."
    exit 1
fi
curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"



# [ec2-user@ip-10-140-241-119 zabbix-scripts]$ sh test3.sh
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100  1249  100  1072  100   177  33561   5541 --:--:-- --:--:-- --:--:-- 40290
# Placing widget at X:0 Y:0 with Width:24 Height:6
# Placing widget at X:0 Y:6 with Width:24 Height:6
# Placing widget at X:0 Y:18 with Width:12 Height:6
# Placing widget at X:0 Y:24 with Width:12 Height:6
# Placing widget at X:0 Y:30 with Width:12 Height:6
# Placing widget at X:0 Y:36 with Width:12 Height:6
# Placing widget at X:0 Y:42 with Width:12 Height:6
# Placing widget at X:0 Y:48 with Width:12 Height:6
# Placing widget at X:0 Y:54 with Width:12 Height:6
# Placing widget at X:12 Y:0 with Width:12 Height:6
# Placing widget at X:12 Y:6 with Width:12 Height:6
# Placing widget at X:12 Y:12 with Width:12 Height:6
# Placing widget at X:12 Y:18 with Width:12 Height:6
# {"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params.","data":"Overlapping widgets at X:12, Y:0 on page #1 of dashboard \"WPTT\".","debug":[{"file":"/usr/share/zabbix/include/classes/api/services/CDashboardGeneral.php","line":337,"function":"exception","class":"CApiService","type":"::"},{"file":"/usr/share/zabbix/include/classes/api/services/CDashboard.php","line":270,"function":"checkWidgets","class":"CDashboardGeneral","type":"->"},{"file":"/usr/share/zabbix/include/classes/api/services/CDashboard.php","line":160,"function":"validateCreate","class":"CDashboard","type":"->"},{"file":"/usr/share/zabbix/include/classes/api/clients/CLocalApiClient.php","line":121,"function":"create","class":"CDashboard","type":"->"},{"file":"/usr/share/zabbix/include/classes/core/CJsonRpc.php","line":75,"function":"callMethod","class":"CLocalApiClient","type":"->"},{"file":"/usr/share/zabbix/api_jsonrpc.php","line":63,"function":"execute","class":"CJsonRpc","type":"->"}]},"id":1}

curl -k -X POST -H 'Content-Type: application/json' \
     -d '{
           "jsonrpc": "2.0",
           "method": "dashboard.get",
           "params": {
             "output": "extend",
             "selectWidgets": "extend",
             "dashboardids": ["YOUR_DASHBOARD_ID"]
           },
           "auth": "'$auth'",
           "id": 1
         }' \
     "$zabbix_url"
