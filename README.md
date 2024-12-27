# NFTables Manager Script

This is a Bash script for managing `nftables` rules on an Ubuntu-based server. It provides an interactive menu for users to perform various operations, including configuring `nftables`, adding or removing rules, saving configurations, and setting up DDoS protection.

## Features

- Manage nftables: Add, delete, flush, and display nftables rules.
- Whitelist and Block IPs: Option to whitelist specific IP addresses (typically used for SSH access).
- DDoS Protection: Implements basic DDoS protection by limiting incoming traffic.
- Save and Load Rules: Save the current nftables configuration and load it later.
- Service Management: Start, stop, and restart the nftables service.
- Add and Block Ports: Add or block specific ports.
- Port Forwarding: Set up port forwarding for specific IP addresses or ports.
- Advanced Options: Additional customization options for firewall settings and configuration.


## Installation

```
sudo bash <(curl -sL https://raw.githubusercontent.com/Niihil/Ytiruces/main/Ytiruces)
```

## Usage

When the script runs, it will present an interactive menu with the following options:

1. **Wizard Nftable: Initializes basic `nftables` tables and chains.
2. **WithList IP: Adds the current IP address to the whitelist (for SSH access or trusted addresses).
3. **Block IP: Blocks a specific IP address from accessing the server.3. **Display Rules: Displays the current `nftables` ruleset.
4. **Display Rules: Displays the current rules in the nftables configuration.
5. **Add Rule: Adds a custom rule to `nftables`.
6. **Delete Rule: Deletes a specified rule from `nftables`.
7. **Flush Rules: Clears all `nftables` rules while preserving SSH connections.
8. **Save Rules: Saves the current `nftables` configuration to a file and enables automatic loading on reboot.
9. **DDoS Protection: Implements basic DDoS protection by limiting traffic.
10. **Open Port: Opens a specific port for inbound or outbound traffic.
11. **Block Port: Blocks a specified port.
12. **Load Conf File: Loads a configuration file to apply pre-defined nftables rules.
13. **Forwarding: Configures port forwarding to redirect traffic from one port to another or to a specific IP.
14. **Exit: Exits the script.


### Example of Commands in the Script:

- To add a rule:
  1. Select option **4** (Add Rule).
  2. Choose the chain (INPUT/OUTPUT/FORWARD).
  3. Choose the protocol (tcp/udp/icmp).
  4. Specify source and destination IP addresses.
  5. Enter the action (ACCEPT/DROP).

- To whitelist your IP address:
  1. Select option **2** (Add With List Ip).
  2. Enter your current IP address.

- To enable DDoS protection:
  1. Select option **9** (DDOS Protection).

## Notes

- **Root Privileges**: The script requires root privileges to modify the `nftables` configuration and restart the `nftables` service.
- **Debian-Only**: The script is designed to run on Ubuntu-based systems (e.g., Ubuntu, Debian). It will exit if another OS is detected.



