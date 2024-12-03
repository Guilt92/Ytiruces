#!/bin/bash 

ORANGE=$(echo -ne '\e[38;5;214m')
BLUE=$(echo -ne '\e[94m')
RED=$(echo -ne '\e[31m')
GREEN=$(echo -ne '\e[32m')
ENDCOLOR=$(echo -ne '\e[0m')
YELLOW=$(echo -ne '\033[0;33m')


check_user_root(){
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}This script must be run as root. Please switch to the root user and try again.${ENDCOLOR}"
        exit 1
    fi
}
check_user_root

detect_distribution() {
    check_user_root
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "${ID}" = "ubuntu" ]]; then
            echo "${BLUE}Ok OS. Installing...${ENDCOLOR}"
            return 0
        fi
        echo "${RED}Unsupported OS. Please install Ubuntu :)${ENDCOLOR}"
        exit 255
    fi
    echo "${RED}Failed to detect OS version file /etc/os-release.${ENDCOLOR}"
    exit 1
}

pkg_install(){
    pkg=nftables
    status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
    if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
        apt install $pkg -y
    fi
}

with_list(){

if [[ ! $USER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || ! { IFS='.'; for i in ${USER_IP//./ }; do [[ $i -le 255 ]]; done; }; then
    echo -e "${RED}The entered IP address is not valid. Please try again.${ENDCOLOR}"
    exit 1
fi

nft add table inet whitelist || { echo -e "${RED}Failed to add table. Please check your nftables configuration.${ENDCOLOR}"; exit 1; }


if [ $? -ne 0 ]; then
    read -p "${BLUE}Enter Ip Address Yourself: ${ENDCOLOR}" USER_IP
    echo -e "${YELLOW}Creating the whitelist table and set...${ENDCOLOR}"
    nft add table inet whitelist
    nft add set inet whitelist whitelist_set { type ipv4_addr\; flags timeout\; }
    nft add chain inet whitelist input { type filter hook input priority 0\; }
    nft add rule inet whitelist input ip saddr @whitelist_set accept

  if [[ "$confirm" == "y" ]]; then
   SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
   sudo nft add rule inet filter input tcp dport $SSH_PORT ct state new,established accept
   sudo nft add rule inet filter output tcp sport $SSH_PORT ct state established accept
   sudo nft add rule inet filter input tcp dport {80, 443, 53} ct state new,established accept
   sudo nft add rule inet filter input udp dport {53} ct state new,established accept

fi

    echo -e "${GREEN}Adding IP address $USER_IP to the whitelist...${ENDCOLOR}"
    nft add element inet whitelist whitelist_set { $USER_IP }
    echo -e "${YELLOW}Saving configuration to $NFTABLES_CONF...${ENDCOLOR}"
    nft list ruleset > $NFTABLES_CONF

    echo -e "${GREEN}Configuration completed successfully! IP address $USER_IP has been added to the whitelist.${ENDCOLOR}"
}


display_rules(){
    check_user_root
    echo "Current nftables Rules: "
    sudo nft list ruleset
}

tables_add(){
    check_user_root
    sudo nft add table ip filter
    sudo nft add table ip nat
    sudo nft add table ip raw
    sudo nft add table ip mangle
}

setup_nftables() {
    sudo nft add chain ip nat prerouting { type nat hook prerouting priority 0 \; }
    sudo nft add chain ip nat postrouting { type nat hook postrouting priority 100 \; }
    sudo nft add chain ip nat output { type nat hook output priority 100 \; }
    sudo nft add chain ip raw prerouting { type filter hook prerouting priority -300 \; }
    sudo nft add chain ip raw output { type filter hook output priority -300 \; }
    sudo nft add chain ip mangle prerouting { type filter hook prerouting priority -150 \; }
    sudo nft add chain ip mangle postrouting { type filter hook postrouting priority -150 \; }

    echo -e "${GREEN}All chains successfully created!${ENDCOLOR}"
}

add_rule(){
    check_user_root
    read -p "${BLUE}Enter Chain (INPUT / OUTPUT / FORWARD): ${ENDCOLOR}" chain
    read -p "${BLUE}Enter protocol (tcp/udp/icmp): ${ENDCOLOR} " protocol
    read -p "${BLUE}Enter source IP (or 0.0.0.0/0 for any): ${ENDCOLOR} " source
    read -p "${BLUE}Enter destination IP (or 0.0.0.0/0 for any): ${ENDCOLOR} " destination
    read -p "${BLUE}Enter destination port (or leave empty for none): ${ENDCOLOR} " port
    read -p "${BLUE}Enter action (ACCEPT/DROP): ${ENDCOLOR} " action

    if [ -z "$port" ]; then
        sudo nft add rule ip filter $chain ip saddr $source daddr $destination $protocol $action 
    else
        sudo nft add rule ip filter $chain ip saddr $source daddr $destination $protocol dport $port $action
    fi
    echo -e "${GREEN}Rule added successfully!${ENDCOLOR}"
}


add_port_user(){
    check_user_root
    read -p "${BLUE}Enter port: ${ENDCOLOR}" port
    sudo nft add rule inet filter input tcp dport $port ct state new,established accept
    sudo nft add rule inet filter output tcp sport $port ct state established accept
    
    while true; do
        read -p "${BLUE}Enter port: ${ENDCOLOR}" port

        if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
            sudo nft add rule inet filter input tcp dport $port ct state new,established accept
            sudo nft add rule inet filter output tcp sport $port ct state established accept
            
            sudo nft add rule inet filter input udp dport $port ct state new,established accept
            sudo nft add rule inet filter output udp sport $port ct state established accept
            
            echo "${GREEN}Port $port has been successfully added for TCP and UDP.${ENDCOLOR}"
            break
        else
            echo "${RED}Invalid port number. Please enter a number between 1 and 65535.${ENDCOLOR}"
        fi
    done
 }


delete_rule() {
    check_user_root
    Display_rules
    read -p "${BLUE}Enter chain (input/output/forward): ${ENDCOLOR}" chain
    read -p "${BLUE}Enter rule number to delete: ${ENDCOLOR}" rule_number
    sudo nft delete rule ip filter "$chain" handle $rule_number
    echo -e "${GREEN}Rule deleted successfully!${ENDCOLOR}"
}

flush_rules() {
    check_user_root
    read -p "${BLUE}Are you sure you want to flush all rules? (y/n): ${ENDCOLOR}" confirm
    if [[ "$confirm" == "y" ]]; then
        SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
        
        sudo nft add rule inet filter input tcp dport $SSH_PORT ct state new,established accept
        sudo nft add rule inet filter output tcp sport $SSH_PORT ct state established accept
        sudo nft add rule inet filter input tcp dport {80, 443, 53} ct state new,established accept
        sudo nft add rule inet filter input udp dport {53} ct state new,established accept

        sudo nft flush ruleset
        
        echo -e "${GREEN}All rules flushed, but SSH connection preserved!${ENDCOLOR}"
    else
        echo -e "${RED}Operation cancelled.${ENDCOLOR}"
    fi
}

save_nftables_rules() {
    check_user_root
    local RULES_FILE="/etc/nftables.conf"
    echo -e "${BLUE}Rules will be saved to: $RULES_FILE${ENDCOLOR}"
    sudo nft list ruleset > $RULES_FILE
    echo -e "${ORANGE}Rules saved to $RULES_FILE${ENDCOLOR}"
    echo -e "${BLUE}Enabling nftables service for automatic rule loading after reboot...${ENDCOLOR}"
    sudo systemctl enable nftables
    echo -e "${BLUE}Checking nftables service status...${ENDCOLOR}"
    sudo systemctl status nftables --no-pager
    echo -e "${BLUE}To manually load the rules from the saved file, use the following command:${ENDCOLOR}"
    echo -e "${GREEN}sudo nft -f $RULES_FILE${ENDCOLOR}"
}

load_rules() {
    check_user_root
    read -p "${BLUE}Enter file name to load rules from: ${ENDCOLOR}" filename
    if [[ -f $filename ]]; then
        sudo nft -f $filename
        echo -e "${GREEN}Rules loaded from $filename${ENDCOLOR}"
    else
        echo -e "${RED}File not found!${ENDCOLOR}"
    fi
}


ddos(){
    check_user_root
    sudo nft add table ip filter
    sudo nft add chain ip filter input { type filter hook input priority 0 \; policy accept \; }
    sudo nft add rule ip filter input ct state new limit rate 50/second burst 100 packets drop
    sudo nft add rule ip filter input ip saddr limit rate 50/second burst 100 packets drop
}

while true
do
    clear
    echo -e "${BLUE}===================================${ENDCOLOR}"
    echo -e "${BLUE}         nftables Manager          ${ENDCOLOR}"
    echo -e "${BLUE}===================================${ENDCOLOR}"
    echo -e "${BLUE}1. Display current rules${ENDCOLOR}"
    echo -e "${BLUE}2. Add a new rule${ENDCOLOR}"
    echo -e "${BLUE}3. Delete a rule${ENDCOLOR}"
    echo -e "${BLUE}4. Flush all rules${ENDCOLOR}"
    echo -e "${BLUE}5. Save rules to file${ENDCOLOR}"
    echo -e "${BLUE}6. DDOS_plus (coming soon)${ENDCOLOR}"
    echo -e "${BLUE}7. Reset nftables (coming soon)${ENDCOLOR}"
    echo -e "${BLUE}8. Load rules from file${ENDCOLOR}"
    echo -e "${RED}9. Exit${ENDCOLOR}"
    echo -e "${BLUE}===================================${ENDCOLOR}"
    
    PS3="Please enter your choice: "
   options=("Display Rules" "Add Rule" "Delete Rule" "Flush Rules" "Save Rules" "DDOS Protection" "Reset Nftables" "Load Rules" "Exit")
 
    select opt in "${options[@]}"; do
        case $opt in
            "Display_Rules")
                display_rules
                break
                ;;
            "Add_Rule")
                add_rule
                break
                ;;
            "Delete_Rule")
                delete_rule
                break
                ;;
            "Flush_Rules")
                flush_rules
                break
                ;;
            "Save_Nftables_Rules")
                save_nftables_rules
                break
                ;;
            "DDOS")

                break
                ;;
            "Reset_Nftables")

                break
                ;;
            "Load_Rules")
                load_rules
                break
                ;;
            "Exit")
                echo -e "${RED}Exiting...${ENDCOLOR}"
                exit
                ;;
            *)
                echo -e "${RED}Invalid option, please try again.${ENDCOLOR}"
                ;;
        esac
    done

    echo -e "${BLUE}Press Enter to return to the main menu...${ENDCOLOR}"
    read -r
done
