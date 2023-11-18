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

# Initialize the dashboard layout parameters
dashboard_max_width=24  # Dashboard width in grid units
dashboard_max_height=62 # Dashboard height in grid units
graph_widget_height=6   # Height of each widget in grid units
graph_widget_width=12   # Width of each widget in grid units

# Initialize variables for widget placement
x=0
y=0
max_widgets_vertically=$((dashboard_max_height / graph_widget_height))
max_widgets_horizontally=$((dashboard_max_width / graph_widget_width))

# Initialize a matrix to keep track of occupied positions
declare -A position_matrix
for ((col = 0; col < max_widgets_horizontally; col++)); do
    for ((row = 0; row < max_widgets_vertically; row++)); do
        position_matrix[$col,$row]=0
    done
done

# Function to find the next available position for a widget
find_next_position() {
    for ((col = 0; col < max_widgets_horizontally; col++)); do
        for ((row = 0; row < max_widgets_vertically; row++)); do
            if [[ ${position_matrix[$col,$row]} -eq 0 ]]; then
                x=$((col * graph_widget_width))
                y=$((row * graph_widget_height))
                position_matrix[$col,$row]=1 # Mark this position as occupied
                return
            fi
        done
    done
    echo "Error: No more space for new widgets."
    exit 1
}

# SVG Graph Types and Host Groups
svggraph_type_list=("Threading: Thread Count" "Threading: Daemon thread count" "Memory: Heap memory maximum size" "Memory: Heap memory used" "Memory: Non-Heap memory used" "Memory: Heap memory committed" "Memory: Non-Heap memory committed" "Threading: Total started thread count" "Threading: Peak thread count" "OperatingSystem: File descriptors opened" "OperatingSystem: Process CPU Load")
host_group=("eu-we1-ca01.ppe.bcs.local" "eu-ce1-c-mgt11.ppe.wpt.local" "eu-ce1-c-zrd11.ppe.wpt.local")

# Loop through each item type to create a widget
for type in "${svggraph_type_list[@]}"; do
    find_next_position # Find the next available position for the widget

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
