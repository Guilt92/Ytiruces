# NFTables Manager Script

This is a Bash script for managing `nftables` rules on an Ubuntu-based server. It provides an interactive menu for users to perform various operations, including configuring `nftables`, adding or removing rules, saving configurations, and setting up DDoS protection.

## Features

- **Check root user**: Ensures the script is run as root.
- **Detect OS**: Verifies if the system is running Ubuntu.
- **Manage nftables**: Add, delete, flush, and display `nftables` rules.
- **Whitelist IP**: Allows the user to whitelist an IP address (typically the one used to SSH into the server).
- **DDoS Protection**: Provides an option to set up basic DDoS protection by rate-limiting incoming traffic.
- **Save and Load Rules**: Enables saving the current `nftables` configuration and loading it at a later time.
- **Service Management**: Starts, stops, and restarts the `nftables` service.
- **Add and Block Ports**: Allows users to add or block specific ports.

## Requirements

- Ubuntu-based system (e.g., Ubuntu, Debian)
- `nftables` installed
- Root access to the server

## Installation

1. Clone this repository to your server:

    ```bash
    git clone https://github.com/Niihil/Ytiruces.git
    ```

2. Make the script executable:

    ```bash
    chmod +x Ytiruces.sh
    ```

3. Run the script:

    ```bash
    sudo ./Ytiruces.sh
    ```

Alternatively, you can use this one-liner to directly download and run the script:

```
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/Niihil/Ytiruces/main/Ytiruces.sh)"
```

## Usage

When the script runs, it will present an interactive menu with the following options:

1. **Wizard Nftable**: Initializes basic `nftables` tables and chains.
2. **Add With List Ip**: Adds the current IP address to the whitelist.
3. **Display Rules**: Displays the current `nftables` ruleset.
4. **Add Rule**: Adds a custom rule to `nftables`.
5. **Delete Rule**: Deletes a specified rule from `nftables`.
6. **Flush Rules**: Clears all `nftables` rules but preserves SSH connection.
7. **Save Rules**: Saves the current `nftables` configuration to a file and enables automatic loading on reboot.
8. **DDOS Protection**: Sets up basic DDoS protection by limiting traffic.
9. **Add Port Number**: Adds an input/output rule for a specified port.
10. **Load Rules**: Loads a set of `nftables` rules from a file.
11. **Block Port**: Blocks a specified port.
12. **Exit**: Exits the script.

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
  1. Select option **8** (DDOS Protection).

## Notes

- **Root Privileges**: The script requires root privileges to modify the `nftables` configuration and restart the `nftables` service.
- **Ubuntu-Only**: The script is designed to run on Ubuntu-based systems (e.g., Ubuntu, Debian). It will exit if another OS is detected.

## Contributing

Feel free to fork this repository, make improvements, or fix bugs. Pull requests are welcome!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
