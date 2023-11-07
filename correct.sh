# Variables for widget placement
top_widget_height=6
top_widget_width=24
graph_widget_height=6
graph_widget_width=12
dashboard_max_width=24  # Dashboard width
dashboard_max_height=62 # Dashboard height
x=0
y=0
i=ped
j=eu-west-1
netgroup=CORE
ENV=patching
TopHostsCount=100

# Add top_hosts widgets
top_hosts_metrics=("CPU" "Memory" "Disk" "Network")
for metric in "${top_hosts_metrics[@]}"; do
  if (( y + top_widget_height > dashboard_max_height )); then
    echo "Error: Widget placement for 'top_hosts' exceeds dashboard height."
    exit 1
  fi
  json_top_hosts_widget='{"type":"tophosts","name":"'$ENV'-'$j'","x":"'$x'","y":"'$y'","width":"11","height":"8","view_mode":"0","fields":[{"type":"0","name":"count","value":"'$TopHostsCount'"},{"type":"1","name":"columns.name.5","value":"Schema Registry"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.item.5","value":"Apache: Service ping"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""},{"type":"1","name":"columnsthresholds.color.5.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.5.0","value":"0"},{"type":"1","name":"columnsthresholds.color.5.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.5.1","value":"1"},{"type":"1","name":"columns.name.4","value":"Agent"},{"type":"0","name":"columns.data.4","value":"1"},{"type":"1","name":"columns.item.4","value":"Zabbix agent availability"},{"type":"1","name":"columns.timeshift.4","value":""},{"type":"0","name":"columns.aggregate_function.4","value":"0"},{"type":"0","name":"columns.display.4","value":"1"},{"type":"0","name":"columns.history.4","value":"1"},{"type":"1","name":"columns.base_color.4","value":""},{"type":"1","name":"columnsthresholds.color.4.0","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.4.0","value":"0"},{"type":"1","name":"columnsthresholds.color.4.1","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.4.1","value":"1"},{"type":"1","name":"columns.item.2","value":"Memory utilization"},{"type":"1","name":"columns.timeshift.2","value":""},{"type":"0","name":"columns.aggregate_function.2","value":"0"},{"type":"0","name":"columns.display.2","value":"3"},{"type":"0","name":"columns.history.2","value":"1"},{"type":"1","name":"columns.name.3","value":"Disk"},{"type":"0","name":"columns.data.3","value":"1"},{"type":"1","name":"columns.item.3","value":"/: Space utilization"},{"type":"1","name":"columns.timeshift.3","value":""},{"type":"0","name":"columns.aggregate_function.3","value":"0"},{"type":"0","name":"columns.display.3","value":"3"},{"type":"0","name":"columns.history.3","value":"1"},{"type":"1","name":"columns.base_color.3","value":""},{"type":"0","name":"column","value":"1"},{"type":"1","name":"columnsthresholds.color.1.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.1.0","value":"50"},{"type":"1","name":"columnsthresholds.color.1.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.1.1","value":"80"},{"type":"1","name":"columnsthresholds.color.1.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.1.2","value":"90"},{"type":"1","name":"columnsthresholds.color.2.0","value":"80FF00"},{"type":"1","name":"columnsthresholds.threshold.2.0","value":"50"},{"type":"1","name":"columnsthresholds.color.2.1","value":"FFBF00"},{"type":"1","name":"columnsthresholds.threshold.2.1","value":"80"},{"type":"1","name":"columnsthresholds.color.2.2","value":"FF465C"},{"type":"1","name":"columnsthresholds.threshold.2.2","value":"95"},{"type":"1","name":"tags.tag.0","value":"env"},{"type":"0","name":"tags.operator.0","value":"1"},{"type":"1","name":"tags.value.0","value":"'$ENV'"},{"type":"1","name":"tags.tag.1","value":"region"},{"type":"0","name":"tags.operator.1","value":"1"},{"type":"1","name":"tags.value.1","value":"'$i'"},{"type":"1","name":"tags.tag.2","value":"project"},{"type":"0","name":"tags.operator.2","value":"1"},{"type":"1","name":"tags.value.2","value":"'$j'"},{"type":"1","name":"columns.min.1","value":"0"},{"type":"1","name":"columns.max.1","value":"100"},{"type":"1","name":"columns.base_color.1","value":"80FF00"},{"type":"1","name":"columns.min.2","value":"0"},{"type":"1","name":"columns.max.2","value":"100"},{"type":"1","name":"columns.base_color.2","value":"80FF00"},{"type":"1","name":"columns.min.3","value":"0"},{"type":"1","name":"columns.max.3","value":"100"},{"type":"1","name":"columnsthresholds.color.3.0","value":"FFFF00"},{"type":"1","name":"columnsthresholds.threshold.3.0","value":"80"},{"type":"1","name":"columnsthresholds.color.3.1","value":"FF8000"},{"type":"1","name":"columnsthresholds.threshold.3.1","value":"90"},{"type":"1","name":"columnsthresholds.color.3.2","value":"FF4000"},{"type":"1","name":"columnsthresholds.threshold.3.2","value":"95"},{"type":"1","name":"columns.name.0","value":"Name"},{"type":"0","name":"columns.data.0","value":"2"},{"type":"0","name":"columns.aggregate_function.0","value":"0"},{"type":"1","name":"columns.base_color.0","value":""},{"type":"1","name":"columns.name.1","value":"CPU"},{"type":"0","name":"columns.data.1","value":"1"},{"type":"1","name":"columns.item.1","value":"CPU utilization"},{"type":"1","name":"columns.timeshift.1","value":""},{"type":"0","name":"columns.aggregate_function.1","value":"0"},{"type":"0","name":"columns.display.1","value":"3"},{"type":"0","name":"columns.history.1","value":"1"},{"type":"1","name":"columns.name.2","value":"Memory"},{"type":"0","name":"columns.data.2","value":"1"}]},'
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
