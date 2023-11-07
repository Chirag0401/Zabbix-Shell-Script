#!/bin/bash
auth="d6165047b19c9421729ea50b34a389f676338173d50960aa829cd6db7899a07c"
zbx_host="operations.ops.ped.local"
zabbix_url="https://${zbx_host}/api_jsonrpc.php"
Dash_name="WPTT"
existing_dash=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "output": ["name", "dashboardid"]},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
data_file="/tmp/zabbix_dash.json"

Get_Dash_CurrentNRequested_Sharing() { :; }
generate_dark_color() { printf "%02x%02x%02x\n" $((RANDOM%128+127)) $((RANDOM%128+127)) $((RANDOM%128+127)); }

case ${existing_dash} in
  *"${Dash_name}"*)
    dash_id=$(echo $existing_dash | grep -o "{[^}]*$Dash_name*" | cut -d ":" -f2 | grep -Eo '[0-9]{1,10}')
    dash_info=$(curl -k -X POST -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "dashboard.get", "params": { "dashboardids": ["'$dash_id'"], "selectPages": "extend", "output": "extend"},"id": 2, "auth": "'$auth'"}' "$zabbix_url")
    page_id=$(echo $dash_info | grep -o '"dashboard_pageid":"[^"]*' | cut -d ":" -f2 | tr -d '"')
    Get_Dash_CurrentNRequested_Sharing $dash_id "${Dash_Sharing_Group[@]}"
    json_part1='{"jsonrpc": "2.0","method": "dashboard.update","params": {"dashboardid": "'$dash_id'","pages": [{"dashboard_pageid": "'$page_id'","widgets": ['
    ;;
  *)
    Get_Dash_CurrentNRequested_Sharing na "${Dash_Sharing_Group[@]}"
    json_part1='{"jsonrpc":"2.0","method":"dashboard.create","params":{"name":"'$Dash_name'","userid":"1","private":"1","display_period":10,"auto_start":1,"pages":[{"widgets":['
    ;;
esac

echo -n "$json_part1" > $data_file

# Variables for widget placement
top_widget_height=6
top_widget_width=24
graph_widget_height=6
graph_widget_width=12
dashboard_max_width=24  # Adjusted dashboard width
dashboard_max_height=64 # Assuming the dashboard height is 64 units
x=0
y=0

# Add top_hosts widgets
top_hosts_metrics=("CPU" "Memory" "Disk" "Network")
for metric in "${top_hosts_metrics[@]}"; do
  if (( y + top_widget_height > dashboard_max_height )); then
    echo "Error: Widget placement for 'top_hosts' exceeds dashboard height."
    exit 1
  fi
  json_top_hosts_widget='{"type":"top_hosts","name":"Top Hosts by '"$metric"'","x":'$x',"y":'$y',"width":'$top_widget_width',"height":'$top_widget_height',"view_mode":0,"fields":[{"type":"0","name":"sort_triggers","value":"1"}]},'
  echo -n "$json_top_hosts_widget" >> $data_file
  y=$((y + top_widget_height))
done

# Calculate starting position for svggraph widgets
x=0  # Reset X position to start at the beginning of the next row
# Ensure y is at the start of the next row if top_hosts widgets didn't exactly fill the last row
if (( y % graph_widget_height != 0 )); then
  y=$(( (y / graph_widget_height + 1) * graph_widget_height ))
fi

# Add svggraph widgets
svggraph_type_list="Threading: Thread Count;Threading: Daemon thread count;Memory: Heap memory maximum size;Memory: Heap memory used;Memory: Non-Heap memory used;Memory: Heap memory committed;Memory: Non-Heap memory committed;Threading: Total started thread count;Threading: Peak thread count;OperatingSystem: File descriptors opened;OperatingSystem: Process CPU Load"
pattern="eu-we1-*.ppe.wpt.local"
IFS=";"
for type in ${svggraph_type_list}; do
  if (( x + graph_widget_width > dashboard_max_width )); then
    x=0
    y=$((y + graph_widget_height))
  fi
  if (( y + graph_widget_height > dashboard_max_height )); then
    echo "Error: Widget placement for 'svggraph' exceeds dashboard height."
    exit 1
  fi
  color=$(generate_dark_color)
  json_svggraph_widget='{"type":"svggraph","name":"'$type'","x":'$x',"y":'$y',"width":'$graph_widget_width',"height":'$graph_widget_height',"view_mode":0,"fields":[{"type":"0","name":"ds.transparency.0","value":"1"},{"type":"0","name":"ds.fill.0","value":"2"},{"type":"0","name":"righty","value":"0"},{"type":"1","name":"ds.hosts.0.0","value":"'$pattern'"},{"type":"1","name":"ds.items.0.0","value":"'$type'"},{"type":"0","name":"ds.type.0","value":"2"},{"type":"0","name":"ds.width.0","value":"4"},{"type":"1","name":"ds.color.0","value":"'$color'"}]},'
  echo -n "$json_svggraph_widget" >> $data_file
  x=$((x + graph_widget_width))
  # Start a new row after every two widgets
  if (( x >= dashboard_max_width )); then
    x=0
    y=$((y + graph_widget_height))
  fi
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
