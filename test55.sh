#!/bin/bash

# Define Zabbix credentials
zbx_host="{$ZABBIX_HOST}"
auth="{$ZABBIX_AUTH}"

# Fetch the region
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')

# Set RegionPattern based on the region
RegionPattern="Error"
if [[ $REGION = *"eu-west"* ]]; then
    RegionPattern="we1"
elif [[ $REGION = *"eu-central"* ]]; then
    RegionPattern="ce1"
fi

# Define Zabbix API Endpoint
ZabbixAPIEndpointDMZ="zabbix-server-api-d-$RegionPattern.$envDomain"

# Check connectivity and define zabbix_url
zabbix_url=""
for x in $zbx_host $ZabbixAPIEndpointDMZ; do
    if curl --connect-timeout 10 -I -k -s "https://$x/" | grep -q "200 OK"; then
        echo "Using Zabbix URL: $x"
        zabbix_url="https://$x/api_jsonrpc.php"
        break
    else
        echo "Not reachable: $x"
    fi
done

# Validate that zabbix_url is set
if [ -z "$zabbix_url" ]; then
    echo "Error: Zabbix URL not set"
    exit 1
fi

# ... [Your existing code for processing, fetching data, etc.]

# Assuming all required variables are set and available here

# Constructing json_part2
json_part2=""
for j in $(echo $project); do
    for i in $(echo $REGION); do
        # Logic for your widgets here, e.g., for 'wpt'
        if [[ $j == "wpt" ]]; then
            # Your widget creation logic
        else
            # Different widget creation logic
        fi
    done
done

# JVM Uptime JSON Construction
jvm_uptime_json='{"type":"1","name":"columns.item.5","value":"Runtime: JVM uptime"},{"type":"1","name":"columns.name.5","value":"JVM Uptime(H:MM)"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""}'

# Add the JVM uptime JSON to json_part2
json_part2="${json_part2}${jvm_uptime_json},"

# Final JSON construction and cURL command
json_final="${json_part1}${json_part2}${json_part3}"
curl -k -X POST -H "Content-Type: application/json" --data "${json_final}" "$zabbix_url"

# Clean up
rm -f "$data_file"
