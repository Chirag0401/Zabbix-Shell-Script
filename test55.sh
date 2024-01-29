#!/bin/bash
#
# ... [previous parts of your script]

# Add JVM Uptime column configuration
jvm_uptime_json='{"type":"1","name":"columns.item.5","value":"Runtime: JVM uptime"},{"type":"1","name":"columns.name.5","value":"JVM Uptime(H:MM)"},{"type":"0","name":"columns.data.5","value":"1"},{"type":"1","name":"columns.timeshift.5","value":""},{"type":"0","name":"columns.aggregate_function.5","value":"0"},{"type":"0","name":"columns.display.5","value":"1"},{"type":"0","name":"columns.history.5","value":"1"},{"type":"1","name":"columns.base_color.5","value":""}'

# [remaining parts of your script where JSON for widgets is constructed]
# For example, where you construct json_part2:

# Original json_part2 construction
json_part2='...'

# Now append the JVM Uptime configuration to json_part2
json_part2="${json_part2}${jvm_uptime_json},"

# ... [continue with the rest of your script]

# [At the end of your script where you're finalizing the JSON and making the curl request]
# Make sure that the JVM Uptime JSON is correctly incorporated

# ...
