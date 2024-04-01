#!/bin/bash

# Thanks to https://vulpinecitrus.info/blog/the-sncf-wifi-api

# Function to display usage
usage() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  (no option)      Show current DNS configuration and ping google.com"
    echo "  -h               Show this help message"
    echo "  -sncf            Use Wifi gateway as DNS server and get some details about the trip"
    echo "  -google          Use Google DNS servers as DNS servers"
    echo "  -nextdns         Go through NextDNS only"
    exit 1
}

# Function to set DNS servers
set_dns() {
    local servers=$1
    if [[ $(uname) == "Linux" ]]; then
        nmcli device modify wlan0 ipv4.dns "$servers" # TBC
    elif [[ $(uname) == "Darwin" ]]; then
        networksetup -setdnsservers Wi-Fi "$servers"
    fi
}

# Function to get current DNS servers
get_dns() {
    echo "DNS config:"
    if [[ $(uname) == "Linux" ]]; then
        nmcli device show wlan0 | grep IP4.DNS # TBC
    elif [[ $(uname) == "Darwin" ]]; then
        networksetup -getdnsservers Wi-Fi
    fi
    # Try to ping google.com
    if ping -c 3 google.com >/dev/null 2>&1; then
        echo -e "\nPinging google.com: OK"
    else
        echo -e "\nPinging google.com: NOK"
    fi
}

# Function to get default gateway
get_gateway() {
    if [[ $(uname) == "Linux" ]]; then
        ip route | awk '/default/ { print $3 }' # TBC
    elif [[ $(uname) == "Darwin" ]]; then
        netstat -rn | grep default | grep -E 'en[0-9]' | awk '{ print $2 }' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"
    fi
}

# Function to accept the sncf portal conditions
accept_connection() {
    # Check the connection status
    if connection_status; then
        echo "Connection already activated."
    else
        response=$(curl -s 'https://wifi.sncf/router/api/connection/activate/auto' \
            -H 'Accept-Language: en-US,en;q=0.9' \
            -H 'Connection: keep-alive' \
            -H 'Origin: https://wifi.sncf' \
            -H 'Referer: https://wifi.sncf/en/internet/login' \
            -H 'Sec-Fetch-Dest: empty' \
            -H 'Sec-Fetch-Mode: cors' \
            -H 'Sec-Fetch-Site: same-origin' \
            -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36' \
            -H 'accept: application/json' \
            -H 'content-type: application/json' \
            -H 'sec-ch-ua: "Google Chrome";v="123", "Not:A-Brand";v="8", "Chromium";v="123"' \
            -H 'sec-ch-ua-mobile: ?0' \
            -H 'sec-ch-ua-platform: "macOS"' \
            --data-raw '{"without21NetConnection":false}')

        # Check if response is not empty
        if [ -n "$response" ]; then
            status=$(echo "$response" | jq -r '.travel.status.active')
            status_description=$(echo "$response" | jq -r '.travel.status.status_description')
            echo -e "Connection activated. Status: $status ($status_description)\n"
        else
            echo -e "Error: No response received.\n"
        fi
    fi
}

# Function to get WiFi connection status
connection_status() {
    response=$(curl -s 'https://wifi.sncf/router/api/connection/status')
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the endpoint"
        return 1
    fi

    # Check if response is not empty
    if [ -n "$response" ]; then
        # Parse and convert JSON fields
        status=$(echo "$response" | jq -r '.active')
        status_description=$(echo "$response" | jq -r '.status_description')
        granted_bandwidth=$(echo "$response" | jq -r '.granted_bandwidth')
        remaining_data=$(echo "$response" | jq -r '.remaining_data')
        consumed_data=$(echo "$response" | jq -r '.consumed_data')
        
        # Convert kilobytes to megabytes
        granted_bandwidth_MB=$(echo "scale=2; $granted_bandwidth / 1024 / 10" | bc)
        remaining_data_MB=$(echo "scale=2; $remaining_data / 1024" | bc)
        consumed_data_MB=$(echo "scale=2; $consumed_data / 1024" | bc)

        # Convert next_reset timestamp to human-readable format
        next_reset=$(echo "$response" | jq -r '.next_reset' | awk '{print int($1/1000)}' | xargs -I{} date -r {} +"%Y-%m-%d %H:%M:%S")

        # Display values
        echo -e "\nStatus: $status ($status_description)"
        echo -e "\nGranted Bandwidth: $granted_bandwidth_MB MB/s"
        echo "Remaining Data: $remaining_data_MB MB"
        echo "Consumed Data: $consumed_data_MB MB"
        echo -e "Next Reset: $next_reset\n"
        # echo -e "\nRaw:\n$(echo $response | jq .)"
        
        # Check if status is true or false and return accordingly
        if [ "$status" == "true" ]; then
            return 0  # Success status
        else
            return 1  # Failure status
        fi
    else
        echo "Error: No response received."
        return 1  # Error status
    fi

}

# Function to get WiFi connection statistics
get_wifi_statistics() {
    response=$(curl -sL "https://wifi.sncf/router/api/connection/statistics")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the endpoint"
        return
    fi
    quality=$(echo "$response" | jq -r '.quality')
    devices=$(echo "$response" | jq -r '.devices')

    echo "WiFi Quality: $quality"
    echo "Number of Devices Connected: $devices"
}

# Function to get bar attendance
get_bar_attendance() {
    response=$(curl -s 'https://wifi.sncf/router/api/bar/attendance')
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the endpoint"
        return
    fi
    is_empty=$(echo "$response" | jq -r '.isBarQueueEmpty')

    if [ "$is_empty" = true ]; then
        echo "Bar queue is empty"
    else
        echo "Bar queue is not empty"
    fi
}

# Function to get train speed and altitude
get_train_gps() {
    response=$(curl -s 'https://wifi.sncf/router/api/train/gps')
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the endpoint"
        return
    fi
    speed=$(echo "$response" | jq -r '.speed')
    altitude=$(echo "$response" | jq -r '.altitude')

    # Convert speed from m/s to km/h
    speed_kmh=$(echo "scale=2; $speed * 3.6" | bc)

    echo "Train speed: $speed_kmh km/h"
    echo "Train altitude: $altitude meters"
}

# Function to get percentage of the trip
get_trip_percentage() {
    response=$(curl -sL "https://wifi.sncf/router/api/train/details")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the endpoint"
        return
    fi
    percentage=$(echo "$response" | jq -Mc '.stops | map(select (.progress != null)) | [ (map(.progress.traveledDistance) | add), (map(.progress.remainingDistance) | add)] | if (.[0] + .[1]) then .[0] / (.[0] + .[1]) * 100 else "EEE" end')
    stops=$(echo "$response" | jq '.stops | length')

    echo "Trip percentage: ${percentage%%.*}%"
    echo "Number of Stops: $(echo $stops - 2 | bc)"
}

# Function to check for delayed stops and display their duration
check_delayed_stops() {
    response=$(curl -sL "https://wifi.sncf/router/api/train/details")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from the endpoint"
        return
    fi
    delayed_stops=$(echo "$response" | jq -r '.stops[] | select(.isDelayed == true) | "\(.label) is delayed by \(.delay) minutes"')

    # Get the theoretical and real arrival dates for the last stop
    last_stop=$(echo "$response" | jq -r '.stops | last')
    theoric_date=$(echo "$last_stop" | jq -r '.theoricDate')
    real_date=$(echo "$last_stop" | jq -r '.realDate')

    # Remove milliseconds and Z from the dates
    theoric_date=$(echo "${theoric_date}" | sed 's/\(.*\)Z/\1/')
    real_date=$(echo "${real_date}" | sed 's/\(.*\)Z/\1/')

    # Convert UTC to Paris time (UTC+1)
    theoric_date_local=$(date -jf "%Y-%m-%dT%H:%M:%S" -v +1H "${theoric_date}" +"%H:%M" 2>/dev/null)
    real_date_local=$(date -jf "%Y-%m-%dT%H:%M:%S" -v +1H "${real_date}" +"%H:%M" 2>/dev/null)

    echo "Theoretical Arrival: ${theoric_date_local}"
    echo "Real Arrival: ${real_date_local}"

    if [ -n "$delayed_stops" ]; then
        echo "$delayed_stops"
    else
        echo "No delayed stops"
    fi
}

# Main script
case "$1" in
    -h)
        usage
        ;;
    -sncf)
        gw=$(get_gateway)
        set_dns "$gw"
        sleep 5
        get_dns
        accept_connection
        get_wifi_statistics
        get_train_gps
        echo
        get_trip_percentage
        check_delayed_stops
        echo
        get_bar_attendance
        ;;
    -google)
        set_dns "8.8.8.8 8.8.4.4"
        sleep 5
        get_dns
        ;;
    -nextdns)
        set_dns "127.0.0.1"
        sleep 5
        get_dns
        ;;
    *)
        # Display current DNS configuration
        get_dns
        ;;
esac

exit 0
