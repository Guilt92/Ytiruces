#!/bin/bash 

# Author:   OuTiS

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
clear
check_user_root
sleep .5;

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
clear 
detect_distribution
sleep 2;
clear


service_nftables() {
    echo "Checking status of nftables service..."
    
    if systemctl is-active --quiet nftables; then
        echo -e "\033[32mService \"nftables\" is already active and running.\033[0m"
        echo "Restarting nftables to ensure configuration is loaded..."
        if systemctl restart nftables; then
            echo -e "\033[32mService \"nftables\" restarted successfully.\033[0m"
        else
            echo -e "\033[31mFailed to restart service \"nftables\".\033[0m"
            return 1
        fi
    else
        echo -e "\033[31mService \"nftables\" is not running. Attempting to start it...\033[0m"
        if systemctl start nftables; then
            echo -e "\033[32mService \"nftables\" started successfully.\033[0m"
            if systemctl enable nftables; then
                echo -e "\033[32mService \"nftables\" enabled to start on boot.\033[0m"
            else
                echo -e "\033[31mFailed to enable service \"nftables\". It might not start on boot.\033[0m"
                return 1
            fi
        else
            echo -e "\033[31mFailed to start service \"nftables\". Please check logs with: journalctl -xeu nftables\033[0m"
            return 1
        fi
    fi

    echo "Verifying nftables configuration..."
    if nft list ruleset > /dev/null 2>&1; then
        echo -e "\033[32mnftables configuration is valid.\033[0m"
    else
        echo -e "\033[31mError in nftables configuration.\033[0m"
        return 1
    fi

    echo -e "\033[32mService \"nftables\" management completed successfully.\033[0m"
    return 0
}


pkg_install(){
    pkg=nftables
    status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
    if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
        apt install $pkg -y
    fi
}

add_with_list_ip(){
    echo -e "${YELLOW}Please enter the IP address you want to whitelist.${ENDCOLOR}"
    echo -e "${YELLOW}Note: This should be the same IP address you are using to SSH into the server.${ENDCOLOR}"
    
    read -p "$(echo -e "${BLUE}Enter your IP address: ${ENDCOLOR}")" USER_IP

    if [[ ! $USER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo -e "${RED}The entered IP address is not valid. Please try again.${ENDCOLOR}"
        exit 1
    else
        IFS='.' read -r -a octets <<< "$USER_IP"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                echo -e "${RED}The entered IP address is not valid. Please try again.${ENDCOLOR}"
                exit 1
            fi
        done
    fi

    echo -e "${YELLOW}You entered IP: ${GREEN}$USER_IP${ENDCOLOR}"
    echo -e "${YELLOW}Please ensure this is the IP you used to SSH into the server.${ENDCOLOR}"

    nft add table inet whitelist || { echo -e "${RED}Failed to add table. Please check your nftables configuration.${ENDCOLOR}"; exit 1; }

    nft add set inet whitelist whitelist_set { type ipv4_addr\; flags timeout\; }
    nft add chain inet whitelist input { type filter hook input priority 0\; }
    nft add rule inet whitelist input ip saddr @whitelist_set accept

    SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
    nft add rule inet filter input tcp dport $SSH_PORT ct state new,established accept
    nft add rule inet filter output tcp sport $SSH_PORT ct state established accept
    nft add rule inet filter input tcp dport {80, 443, 53} ct state new,established accept
    nft add rule inet filter input udp dport {53} ct state new,established accept

    export USER_IP
    export SSH_PORT

    echo -e "${GREEN}Adding IP address $USER_IP to the whitelist...${ENDCOLOR}"
    nft add element inet whitelist whitelist_set { $USER_IP }
    
    NFTABLES_CONF="/etc/nftables.conf"
    if [ -f $NFTABLES_CONF ]; then
        echo -e "${YELLOW}Saving configuration to $NFTABLES_CONF...${ENDCOLOR}"
        nft list ruleset > $NFTABLES_CONF
    else 
        echo -e "${RED}File not found. Creating the file and saving configuration.${ENDCOLOR}"
        touch $NFTABLES_CONF
        nft list ruleset > $NFTABLES_CONF
    fi 

    echo -e "${GREEN}Configuration completed successfully! IP address $USER_IP has been added to the whitelist.${ENDCOLOR}"
}


display_rules(){
    clear 
    echo "${GREEN}Current nftables Rules: ${ENDCOLOR}" 
     nft list ruleset
}

wizard_nftables(){
    nft add table inet filter
    nft add chain inet filter input { type filter hook input priority 0 \; }
    nft add chain inet filter output { type filter hook output priority 0 \; }
    nft add chain inet filter forward { type filter hook forward priority 0 \; }
    
    nft add table inet nat
    nft add chain inet nat prerouting { type nat hook prerouting priority 0 \; }
    nft add chain inet nat postrouting { type nat hook postrouting priority 100 \; }

    nft add table inet raw
    nft add chain inet raw prerouting { type filter hook prerouting priority -300 \; }
    nft add chain inet raw output { type filter hook output priority -300 \; }

    nft add table inet mangle
    nft add chain inet mangle prerouting { type filter hook prerouting priority -150 \; }
    nft add chain inet mangle postrouting { type filter hook postrouting priority -150 \; }
    echo -e "${GREEN}All chains & table successfully created!${ENDCOLOR}"

}
add_rule(){
    read -p "${BLUE}Enter Chain (INPUT / OUTPUT / FORWARD): ${ENDCOLOR}" chain
    read -p "${BLUE}Enter protocol (tcp/udp/icmp): ${ENDCOLOR} " protocol
    read -p "${BLUE}Enter source IP (or 0.0.0.0/0 for any): ${ENDCOLOR} " source
    read -p "${BLUE}Enter destination IP (or 0.0.0.0/0 for any): ${ENDCOLOR} " destination
    read -p "${BLUE}Enter destination port (or leave empty for none): ${ENDCOLOR} " port
    read -p "${BLUE}Enter action (ACCEPT/DROP): ${ENDCOLOR} " action

    if [ -z "$port" ]; then
         nft add rule ip filter $chain ip saddr $source daddr $destination $protocol $action 
    else
         nft add rule ip filter $chain ip saddr $source daddr $destination $protocol dport $port $action
    fi
    echo -e "${GREEN}Rule added successfully!${ENDCOLOR}"
}


add_port_user() {
    read -p "${BLUE}Enter port: ${ENDCOLOR}" PORT

    if [[ ! $PORT =~ ^[0-9]+$ || $PORT -lt 1 || $PORT -gt 65535 ]]; then
        echo -e "${RED}Invalid port number. Please enter a number between 1 and 65535.${ENDCOLOR}"
        return
    fi

    nft add rule inet filter input tcp dport $PORT ct state new,established accept || {
        echo -e "${RED}Failed to add input rule for port $PORT.${ENDCOLOR}"
        return
    }
    nft add rule inet filter output tcp sport $PORT ct state established accept || {
        echo -e "${RED}Failed to add output rule for port $PORT.${ENDCOLOR}"
        return
    }

    echo -e "${GREEN}Port $PORT has been successfully added.${ENDCOLOR}"
    exit
}



delete_rule() {
    echo ""

    display_rules
    echo ""
    read -p "${BLUE}Enter chain (input/output/forward): ${ENDCOLOR}" chain

    if [[ ! "$chain" =~ ^(input|output|forward)$ ]]; then
        echo -e "${RED}Invalid chain. Please choose 'input', 'output', or 'forward'.${ENDCOLOR}"
        return
    fi

    echo -e "${YELLOW}Displaying current rules in the $chain chain...${ENDCOLOR}"
    nft list chain inet filter $chain

    read -p "${BLUE}Enter rule number to delete: ${ENDCOLOR}" rule_number

    nft delete rule inet filter $chain handle $rule_number || {
        echo -e "${RED}Failed to delete rule. Please make sure the rule number is correct.${ENDCOLOR}"
        return
    }

    echo -e "${GREEN}Rule deleted successfully!${ENDCOLOR}"
}


flush_rules() {
    BACKUP_FILE="/etc/nftables.conf.backup"
    nft list ruleset > $BACKUP_FILE || { echo -e "${RED}Failed to create backup.${ENDCOLOR}"; exit 1; }

    read -p "${BLUE}Are you sure you want to flush all rules? (y/n): ${ENDCOLOR}" confirm
    if [[ "$confirm" == "y" ]]; then
        SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
        
        nft add table inet filter || true
        nft add chain inet filter input { type filter hook input priority 0\; } || true
        nft add chain inet filter output { type filter hook output priority 0\; } || true
        
        nft add rule inet filter input tcp dport $SSH_PORT ct state new,established accept
        nft add rule inet filter output tcp sport $SSH_PORT ct state established accept
        nft add rule inet filter input tcp dport {80, 443, 53} ct state new,established accept
        nft add rule inet filter input udp dport {53} ct state new,established accept
        
        nft flush ruleset
        echo -e "${GREEN}All rules flushed, but SSH connection preserved!${ENDCOLOR}"
    else
        echo -e "${RED}Operation cancelled.${ENDCOLOR}"
    fi
}

save_nftables_rules() {
    local RULES_FILE="/etc/nftables.conf"
    echo -e "${BLUE}Rules will be saved to: $RULES_FILE${ENDCOLOR}"
     nft list ruleset > $RULES_FILE
    echo -e "${ORANGE}Rules saved to $RULES_FILE${ENDCOLOR}"
    echo -e "${BLUE}Enabling nftables service for automatic rule loading after reboot...${ENDCOLOR}"
     systemctl enable nftables
    echo -e "${BLUE}Checking nftables service status...${ENDCOLOR}"
     systemctl status nftables --no-pager
    echo -e "${BLUE}To manually load the rules from the saved file, use the following command:${ENDCOLOR}"
    echo -e "${GREEN} nft -f $RULES_FILE${ENDCOLOR}"
}

load_rules() {
    read -p "${BLUE}Enter file name to load rules from: ${ENDCOLOR}" filename
    if [[ -f $filename ]]; then
         nft -f $filename
        echo -e "${GREEN}Rules loaded from $filename${ENDCOLOR}"
    else
        echo -e "${RED}File not found!${ENDCOLOR}"
    fi
}


ddos(){
    
    nft add table ip raw
    nft add set ip raw banned_ips { type ipv4_addr\; flags timeout\; timeout 12h\; }
    nft add chain ip raw prerouting { type filter hook prerouting priority -300 \; }
    nft add rule ip raw prerouting ip saddr @banned_ips drop
    nft add rule ip raw prerouting limit rate 1000/second add @banned_ips { ip saddr }
    nft add rule ip raw prerouting limit rate 500/second log prefix "Potential DDoS: " level warning
    nft add rule ip raw prerouting udp limit rate 500/second burst 50 packets drop
    nft add rule ip raw prerouting tcp flags syn limit rate 50/second burst 10 drop
    nft list ruleset > NFTABLES_CONF
}



while true; do
    echo " "
    echo " "    
    echo -e "${ORANGE}\e[5m╔═══════════════════════════════════════════════════════════╗${ENDCOLOR}" 
    echo -e "                    ${GREEN} 🔥 NFTables Manager 🔥   ${ENDCOLOR}" 
    echo -e "${ORANGE}\e[5m╚═══════════════════════════════════════════════════════════╝${ENDCOLOR}" 
    echo " "
    echo "============================"
    echo -e "${RED}1. ${ENDCOLOR} Wizard Nftable"
    echo -e "${RED}2. ${ENDCOLOR} Add With List Ip"
    echo -e "${RED}3. ${ENDCOLOR} Display Rules"
    echo -e "${RED}4. ${ENDCOLOR} Add Rule"
    echo -e "${RED}5. ${ENDCOLOR} Delete Rule"
    echo -e "${RED}6. ${ENDCOLOR} Flush Rules"                             
    echo -e "${RED}7. ${ENDCOLOR} Save Rules"                              
    echo -e "${RED}8. ${ENDCOLOR} DDOS Protection"                         
    echo -e "${RED}9. ${ENDCOLOR} Add Port Number"                         
    echo -e "${RED}10.${ENDCOLOR} Load Rules"                              
    echo -e "${RED}11.${ENDCOLOR} Exit"                                    
    echo                                                                   
    read -p "$(echo -e "${BLUE}Please enter your choice: ${ENDCOLOR}")" choice

    case $choice in
        1) pkg_install; sleep 1; clear; wizard_nftables; service_nftables; break ;;
        2) add_with_list_ip; sleep 1; service_nftables; break ;;        
        3) display_rules; break ;;                                        
        4) add_rule; service_nftables; break ;;                           
        5) delete_rule; service_nftables; break ;;                        
        6) flush_rules; sleep 1; service_nftables; break ;;              
        7) save_nftables_rules; sleep 1; service_nftables; break ;;  
        8) ddos; break ;;                                                  
        9) add_port_user; sleep 1; service_nftables; break ;;              
        10) load_rules; sleep 1; service_nftables; break ;;
        11) sleep 1; clear; echo "Exiting..."; exit ;;
        *) echo -e "${RED}Invalid option, please try again.${ENDCOLOR}" ;;
    esac

    sleep 1
done

