# WiFi-OnRails

This script provides various functionalities related to the SNCF WiFi INOUI service, allowing users to manage their connection, check trip details, and configure DNS settings.

## Prerequisites

- **jq**: A lightweight and flexible command-line JSON processor. It is used to parse JSON responses from SNCF WiFi APIs.
- **curl**: A command-line tool and library for transferring data with URLs. It is used to make HTTP requests to SNCF WiFi APIs.
- **Network Setup Tool (networksetup)**: A command-line utility on macOS used to configure network settings, including DNS servers.

## Usage

```bash
./wifi_sncf.sh [OPTION]
```

### Options:

- **(no option)**: Displays the current DNS configuration and pings google.com.
- **-h**: Displays help information.
- **-sncf**: Uses the WiFi gateway as the DNS server and retrieves trip details.
- **-google**: Uses Google DNS servers as the DNS servers.
- **-nextdns**: Sets DNS to go through [NextDNS](https://my.nextdns.io) only.

## Functions:

### 1. `accept_connection()`

Activates the SNCF WiFi connection by accepting the portal conditions.

### 2. `connection_status()`

Retrieves the WiFi connection status, including granted bandwidth, remaining data, consumed data, and next reset time.

### 3. `get_wifi_statistics()`

Retrieves WiFi statistics such as quality and the number of devices connected.

### 4. `get_train_gps()`

Retrieves the train's current speed and altitude.

### 5. `get_trip_percentage()`

Calculates the percentage of the trip completed based on the traveled distance.

### 6. `check_delayed_stops()`

Checks for delayed stops during the trip and displays their duration.

### 7. `get_bar_attendance()`

Checks if the bar queue is empty or not. (not very accurate)

## Example Usage:

```bash
$ ./wifi_sncf.sh -sncf
```

**Output:**
```
DNS config:
10.122.0.1

Pinging google.com: NOK

Status: true (identifier has existing grant)

Granted Bandwidth: 9.76 MB/s
Remaining Data: 106.15 MB
Consumed Data: 893.84 MB
Next Reset: 14:09:09

WiFi Quality: 5
Number of Devices Connected: 126
Train speed: 82.598 km/h
Train altitude: 356.63 meters

Trip percentage: 91%
Number of Stops: 1
Theoretical Arrival: 13:13
Real Arrival: 13:18
Delayed stops: Grenoble is delayed by 5 minutes

Bar queue is not empty
```

## Acknowledgments

Thanks to [Vulpine Citrus](https://vulpinecitrus.info/blog/the-sncf-wifi-api) for insights into the SNCF WiFi API.
