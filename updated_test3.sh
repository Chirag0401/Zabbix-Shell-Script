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
  json_top_hosts_widget='[JSON content for top_hosts widget here]'
  
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
json_problem_widgets='[JSON content for problems widget here]'
echo -n "$json_problem_widgets" >> $data_file

# Update Y position for next widget
x=0
y=$((y + 4))

# Ensure y is at the start of the next row if top_hosts widgets didn't exactly fill the last row
if (( y % graph_widget_height != 0 )); then
  y=$(( (y / graph_widget_height + 1) * graph_widget_height ))
fi

# ... [previous code]

# Add svggraph widgets
svggraph_type_list=("Threading: Thread Count" "Threading: Daemon thread count" "Memory: Heap memory maximum size" "Memory: Heap memory used" "Memory: Non-Heap memory used" "Memory: Heap memory committed" "Memory: Non-Heap memory committed" "Threading: Total started thread count" "Threading: Peak thread count" "OperatingSystem: File descriptors opened" "OperatingSystem: Process CPU Load")
host_group=("eu-we1-ca01.ppe.bcs.local" "eu-ce1-c-mgt11.ppe.wpt.local" "eu-ce1-c-zrd11.ppe.wpt.local")

for type in "${svggraph_type_list[@]}"; do
  if (( x + graph_widget_width > dashboard_max_width )); then
    x=0
    y=$((y + graph_widget_height))
  fi
  if (( y + graph_widget_height > dashboard_max_height )); then
    echo "Error: Widget placement for 'svggraph' exceeds dashboard height."
    exit 1
  fi

  # Start the JSON for the svggraph widget
  json_svggraph_widget="{\"type\":\"svggraph\",\"name\":\"$type\",\"x\":$x,\"y\":$y,\"width\":$graph_widget_width,\"height\":$graph_widget_height,\"view_mode\":0,\"fields\":["

  # Add datasets for each host
  for host in "${host_group[@]}"; do
    color=$(generate_dark_color) # Color for the dataset, you might want to make this static if you need consistency
    json_svggraph_widget+="{\"type\":\"1\",\"name\":\"ds.hosts.0.0\",\"value\":\"$host\"},{\"type\":\"1\",\"name\":\"ds.items.0.0\",\"value\":\"$type\"},{\"type\":\"0\",\"name\":\"ds.transparency.0\",\"value\":\"1\"},{\"type\":\"0\",\"name\":\"ds.fill.0\",\"value\":\"2\"},{\"type\":\"0\",\"name\":\"righty\",\"value\":\"0\"},{\"type\":\"0\",\"name\":\"ds.type.0\",\"value\":\"2\"},{\"type\":\"0\",\"name\":\"ds.width.0\",\"value\":\"4\"},{\"type\":\"1\",\"name\":\"ds.color.0\",\"value\":\"$color\"},"
  done

  # Remove the last comma and close the JSON object
  json_svggraph_widget="${json_svggraph_widget%,}]},"

  echo "Placing widget at X:$x Y:$y with Width:$graph_widget_width Height:$graph_widget_height"
  echo -n "$json_svggraph_widget" >> $data_file

  # Increment y for the next widget, reset x if necessary
  y=$((y + graph_widget_height))
  if (( y >= dashboard_max_height )); then
    x=$((x + graph_widget_width))
    y=0
  fi
done

# ... [rest of the code]




# Finalize the JSON file
sed -i '$ s/,$//' $data_file  # Remove the last comma
echo -n ']}]},"auth":"'$auth'","id":1}' >> $data_file

# Validate and send the JSON to Zabbix
if ! jq empty $data_file; then
    echo "JSON is invalid. Please check the $data_file file for syntax errors."
    exit 1
fi
curl -k -X POST -H "Content-Type: application/json" --data @$data_file "$zabbix_url"



#[ec2-user@ip-10-140-241-119 zabbix-scripts]$ sh test3.sh
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100  1249  100  1072  100   177  24712   4080 --:--:-- --:--:-- --:--:-- 29046
# Placing widget at X:0 Y:0 with Width:24 Height:6
# Placing widget at X:0 Y:6 with Width:24 Height:6
# Placing widget at X:0 Y:18 with Width:12 Height:6
# Placing widget at X:12 Y:18 with Width:12 Height:6
# Placing widget at X:0 Y:24 with Width:12 Height:6
# Placing widget at X:12 Y:24 with Width:12 Height:6
# Placing widget at X:0 Y:30 with Width:12 Height:6
# Placing widget at X:12 Y:30 with Width:12 Height:6
# Placing widget at X:0 Y:36 with Width:12 Height:6
# Placing widget at X:12 Y:36 with Width:12 Height:6
# Placing widget at X:0 Y:42 with Width:12 Height:6
# Placing widget at X:12 Y:42 with Width:12 Height:6
# Placing widget at X:0 Y:48 with Width:12 Height:6
# Placing widget at X:12 Y:48 with Width:12 Height:6
# Placing widget at X:0 Y:54 with Width:12 Height:6
# Placing widget at X:12 Y:54 with Width:12 Height:6
# Error: Widget placement for 'svggraph' exceeds dashboard height.
