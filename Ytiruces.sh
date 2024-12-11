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

add_ip_withlist(){
    echo -e "${YELLOW}Please enter the IP address you want to whitelist.${ENDCOLOR}"
    echo -e "${YELLOW}Note: This should be the same IP address you are using to SSH into the server.${ENDCOLOR}"

    read -p "$(echo -e "${BLUE}Enter your IP address: ${ENDCOLOR}")" USER_IP

    if [[ -z "$USER_IP" ]]; then
        echo -e "${RED}Error: No IP entered. Exiting...${ENDCOLOR}"
        exit 1
    fi

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

    nftwizard
    echo -e "${YELLOW}You entered IP: ${GREEN}$USER_IP${ENDCOLOR}"
    echo -e "${YELLOW}Please ensure this is the IP you used to SSH into the server.${ENDCOLOR}"
    
    nft add table inet whitelist || { echo -e "${RED}Failed to add table. Please check your nftables configuration.${ENDCOLOR}"; exit 1; }
    nft add table inet raw 2>/dev/null
    nft add set inet raw whitelist_set { type ipv4_addr\; flags timeout\; }
    
    #nft add set inet whitelist whitelist_set { type ipv4_addr\; flags timeout\; }
    #nft add chain inet whitelist input { type filter hook input priority -400\; }
    nft add chain inet raw prerouting { type filter hook prerouting priority -500 \; }
    nft add chain inet raw input { type filter hook input priority -500 \; }

    #nft add rule inet whitelist input ip saddr @whitelist_set accept
    nft add rule inet raw prerouting ip saddr @whitelist_set accept
    
    SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
    SSH_PORT=${SSH_PORT:-22}

    nft add rule inet filter input ct state new,established tcp dport $SSH_PORT accept
    nft add rule inet filter output ct state established tcp sport $SSH_PORT accept
    nft add rule inet filter input ct state new,established tcp dport {80, 443, 53} accept
    nft add rule inet filter input ct state new,established udp dport {53} accept

    export USER_IP
    export SSH_PORT

    echo -e "${GREEN}Adding IP address $USER_IP to the whitelist...${ENDCOLOR}"
    nft delete element inet blacklist blacklist_set { $USER_IP }
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

add_ip_block_list(){
    echo -e "${YELLOW}Please enter the IP address you want to block.${ENDCOLOR}"

    read -p "$(echo -e "${BLUE}Enter the IP address to block: ${ENDCOLOR}")" USER_IP

    if [[ -z "$USER_IP" ]]; then
        echo -e "${RED} No Ip Entered. EXiting ....  ${ENDCOLOR}"
        exit 1 
    fi 

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
    echo -e "${RED}Blocking this IP address...${ENDCOLOR}"

    nft add table inet blacklist || { echo -e "${RED}Failed to add table. Please check your nftables configuration.${ENDCOLOR}"; exit 1; }
    nft add set inet blacklist blacklist_set { type ipv4_addr\; flags timeout\; }
    nft add chain inet blacklist input { type filter hook input priority 0\; }
    nft add rule inet blacklist input ip saddr @blacklist_set drop

    echo -e "${GREEN}Adding IP address $USER_IP to the block list...${ENDCOLOR}"
    nft add element inet blacklist blacklist_set { $USER_IP }

    NFTABLES_CONF="/etc/nftables.conf"
    if [ -f $NFTABLES_CONF ]; then
        echo -e "${GREEN}Saving configuration to $NFTABLES_CONF...${ENDCOLOR}"
        nft list ruleset > $NFTABLES_CONF
    else
        echo -e "${RED}File not found. Creating the file and saving configuration.${ENDCOLOR}"
        touch $NFTABLES_CONF
        nft list ruleset > $NFTABLES_CONF
    fi

    echo -e "${GREEN}Configuration completed successfully! IP address $USER_IP has been added to the block list.${ENDCOLOR}"
}




display_rules(){
    clear 
    echo "${GREEN}Current nftables Rules: ${ENDCOLOR}" 
     nft list ruleset
}



backup_conf_nft(){
    
if [ -f /etc/nftables.conf ]; then
    echo -e "${GREEN}File Config nftables exists and backup config nftables ${ENDCOLOR}"
    backup_file="/etc/nftables.conf-old"
    if [ -f "$backup_file" ]; then
        timestamp=$(date +%Y%m%d%H%M%S) 
        mv "$backup_file" "/etc/nftables.conf-old.$timestamp"
        echo -e "${YELLOW}Backup file already exists. Renamed to /etc/nftables.conf-old.$timestamp${ENDCOLOR}"
    fi
    
    mv /etc/nftables.conf "$backup_file"
    echo -e "${GREEN}Backup created: $backup_file${ENDCOLOR}"
else
    echo -e "${RED}File does not exist${ENDCOLOR}"
fi
    touch /etc/nftables.conf
}

nftwizard(){
backup_conf_nft
  nft list tables | grep -q 'inet filter' || nft add table inet filter
  nft add chain inet filter input { type filter hook input priority 0 \; }
  nft add chain inet filter output { type filter hook output priority 0 \; }
  nft add chain inet filter forward { type filter hook forward priority 0 \; }
  nft list tables | grep -q 'inet nat' || nft add table inet nat
  nft add chain inet nat prerouting { type nat hook prerouting priority 0\; }
  nft add chain inet nat postrouting { type nat hook postrouting priority 100\; }

  nft list tables | grep -q 'inet raw' || nft add table inet raw
  nft add chain inet raw prerouting { type filter hook prerouting priority -300\; }
  nft add chain inet raw output { type filter hook output priority -300\; }

  nft list tables | grep -q 'inet mangle' || nft add table inet mangle
  nft add chain inet mangle prerouting { type filter hook prerouting priority -150\; }
  nft add chain inet mangle postrouting { type filter hook postrouting priority -150\; }

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


add_port_withlist() {
  read -p "${BLUE}Enter port: ${ENDCOLOR}" PORT

  if [[ ! $PORT =~ ^[0-9]+$ || $PORT -lt 1 || $PORT -gt 65535 ]]; then
    echo -e "${RED}Invalid port number. Please enter a number between 1 and 65535.${ENDCOLOR}"
    return
  fi

  if [[ -z "$PORT" ]]; then
    echo -e "${RED}Error: No $PORT entered. Exiting...${ENDCOLOR}"
    exit 1
  fi

  #if nft -a list ruleset | grep -q "tcp dport $PORT ct state new,established accept"; then
  #  echo -e "${BLUE}Port $PORT is already in the whitelist.${ENDCOLOR}"
  #  return
  # fi
  # nft add rule inet filter input tcp dport $PORT ct state new,established accept
  # nft add rule inet filter output tcp sport $PORT ct state established accept
 
  nft insert rule inet filter input position 0 tcp dport $PORT  accept
  nft insert rule inet filter output position 0 tcp dport $PORT  accept

  # INPUT_RULE_HANDLE=$(nft list ruleset | grep -i "tcp dport $PORT ct state new,established accept" | grep -oP "(?<=handle )\d+")
  # OUTPUT_RULE_HANDLE=$(nft list ruleset | grep -i "tcp sport $PORT ct state established accept" | grep -oP "(?<=handle )\d+")

  echo -e "${GREEN}Port $PORT has been successfully added to the whitelist.${ENDCOLOR}"
 # echo "Input rule handle: $INPUT_RULE_HANDLE"
 # echo "Output rule handle: $OUTPUT_RULE_HANDLE"

}


block_port() {
  read -p "${BLUE}Enter port to block: ${ENDCOLOR}" PORT

  if [[ ! $PORT =~ ^[0-9]+$ || $PORT -lt 1 || $PORT -gt 65535 ]]; then
    echo -e "${RED}Invalid port number. Please enter a number between 1 and 65535.${ENDCOLOR}"
    return
  fi

  # INPUT_RULE_HANDLE=$(nft list ruleset | grep -i "tcp dport $PORT ct state new,established accept" | grep -oP "(?<=handle )\d+")
  # OUTPUT_RULE_HANDLE=$(nft list ruleset | grep -i "tcp sport $PORT ct state established accept" | grep -oP "(?<=handle )\d+")

  # if [ -n "$INPUT_RULE_HANDLE" ]; then
  # nft delete rule inet filter input handle $INPUT_RULE_HANDLE
  #  echo -e "${GREEN}Input rule for port $PORT has been successfully deleted.${ENDCOLOR}"
  # else
  #  echo -e "${RED}No input rule found for port $PORT in the whitelist.${ENDCOLOR}"
  # fi

  #if [ -n "$OUTPUT_RULE_HANDLE" ]; then
  # nft delete rule inet filter output handle $OUTPUT_RULE_HANDLE
  # echo -e "${GREEN}Output rule for port $PORT has been successfully deleted.${ENDCOLOR}"
  # else
  # echo -e "${RED}No output rule found for port $PORT in the whitelist.${ENDCOLOR}"
  # fi
  #
  #
  # nft add rule inet filter input tcp dport $PORT drop
  # nft add rule inet filter output tcp sport $PORT drop

   nft insert rule inet filter input position 0 tcp dport $PORT  drop
   nft insert rule inet filter output position 0 tcp dport $PORT  drop

   echo -e "${GREEN}Port $PORT has been successfully blocked.${ENDCOLOR}"

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



flush_all_rules() {
  BACKUP_FILE="/etc/nftables.conf.backup"
  nft list ruleset > $BACKUP_FILE || { echo -e "${RED}Failed to create backup.${ENDCOLOR}"; exit 1; }

  read -p "${BLUE}Are you sure you want to flush all rules? (y/n): ${ENDCOLOR}" confirm
  if [[ "$confirm" == "y" ]]; then
    
    SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
    SSH_PORT=${SSH_PORT:-22}
    
    nft flush ruleset
    echo -e "${YELLOW}All rules flushed.${ENDCOLOR}" 
    nft delete table inet whitelist 2>/dev/null
    nft delete table inet blacklist 2>/dev/null
    nftwizard
    nft add rule inet filter input ip saddr 0.0.0.0/0 tcp dport $SSH_PORT ct state new,established accept
    nft add rule inet filter output ip daddr 0.0.0.0/0 tcp sport $SSH_PORT ct state established accept
    nft add rule inet filter input ip saddr 0.0.0.0/0 tcp dport {80, 443, 53} ct state new,established accept
    nft add rule inet filter input ip saddr 0.0.0.0/0 udp dport {53} ct state new,established accept


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

load_rules_file() {
    read -p "${BLUE}Enter file name to load rules from: ${ENDCOLOR}" filename
    if [[ -f $filename ]]; then
         nft -f $filename
        echo -e "${GREEN}Rules loaded from $filename${ENDCOLOR}"
    else
        echo -e "${RED}File not found!${ENDCOLOR}"
    fi
}


ddos(){
         nft add table inet raw 2>/dev/null
         nft add set inet raw blacklist { type ipv4_addr\; flags timeout\; timeout 30m\; }
         nft add chain inet raw prerouting { type filter hook prerouting priority -300 \; }
         nft add chain inet raw input { type filter hook input priority -300 \; }
         nft add chain inet raw output { type filter hook output priority -300 \; }
         nft add rule inet raw prerouting ip saddr @whitelist_set accept         
         nft add rule inet raw prerouting ip protocol tcp tcp flags syn limit rate over 30/minute add @blacklist { ip saddr }
         nft add rule inet raw prerouting ip protocol udp limit rate over 30/minute add @blacklist { ip saddr }
         nft add rule inet raw prerouting ip protocol icmp limit rate over 30/minute add @blacklist { ip saddr }
         nft add rule inet raw prerouting ip protocol tcp ct state new limit rate over 50/minute add @blacklist { ip saddr }   
         nft add rule inet raw prerouting ip saddr @blacklist drop
         nft add rule inet raw prerouting ip saddr @blacklist log prefix "DDoS Attack: " counter
         nft add rule inet raw prerouting ip saddr @blacklist tcp dport { 22, 80, 443, 53 } limit rate over 10/minute add @blacklist { ip saddr }
         nft add rule inet raw prerouting ip saddr @blacklist ct state invalid drop
         
         nft list ruleset > /etc/nftables.conf
    }   


reload_nft() {
    echo -e "${YELLOW}Reloading nftables rules...${ENDCOLOR}"
    if systemctl reload nftables; then
        echo -e "${GREEN}NFTables rules reloaded successfully.${ENDCOLOR}"
    else
        echo -e "${RED}Failed to reload NFTables rules. Please check your configuration.${ENDCOLOR}"
        exit 1
    fi
}

forwarding() {
    read -p "Enter the source IP (leave empty for any): " SRC_IP
    read -p "Enter the destination IP: " DEST_IP
    read -p "Enter the source port: " SRC_PORT
    read -p "Enter the destination port: " DEST_PORT

    if [ -z "$SRC_IP" ]; then
        SRC_IP="0.0.0.0/0"
    fi

    nft add table inet raw 2>/dev/null
    nft add chain inet raw prerouting { type filter hook prerouting priority -300 \; } 2>/dev/null
    nft add chain inet raw postrouting { type filter hook postrouting priority 100 \; } 2>/dev/null

    nft add rule inet raw prerouting ip saddr "$SRC_IP" tcp dport "$SRC_PORT" \
        dnat to "$DEST_IP":"$DEST_PORT"

    nft add rule inet raw postrouting ip daddr "$DEST_IP" tcp dport "$DEST_PORT" \
        masquerade

    echo -e "${GREEN}Forwarding rule created successfully! ${ENDCOLOR} "
}

while true; do
    sleep 5
    clear  
    echo " "
    echo " "    
    echo -e "${ORANGE}\e[5m╔═══════════════════════════════════════════════════════════╗${ENDCOLOR}" 
    echo -e "                    ${GREEN} 🔥 NFTables Manager 🔥   ${ENDCOLOR}" 
    echo -e "${ORANGE}\e[5m╚═══════════════════════════════════════════════════════════╝${ENDCOLOR}" 
    echo " "
    echo "============================"
    echo -e "${RED}1. ${ENDCOLOR} Wizard Nftable"
    echo -e "${RED}2. ${ENDCOLOR} Add Ip WithList"
    echo -e "${RED}3. ${ENDCOLOR} Add Block List Ip"
    echo -e "${RED}4. ${ENDCOLOR} Display Rules"
    echo -e "${RED}5. ${ENDCOLOR} Add Rule"
    echo -e "${RED}6. ${ENDCOLOR} Delete Rule"
    echo -e "${RED}7. ${ENDCOLOR} Flush All Rules"                             
    echo -e "${RED}8. ${ENDCOLOR} Save Rules"                              
    echo -e "${RED}9. ${ENDCOLOR} DDOS Protection"                         
    echo -e "${RED}10.${ENDCOLOR} Add WithList Port"                         
    echo -e "${RED}11.${ENDCOLOR} Load Rules File" 
    echo -e "${RED}12.${ENDCOLOR} Block Port" 
    echo -e "${RED}13.${ENDCOLOR} Exit"                                    
    echo                                                                   
    read -p "$(echo -e "${BLUE}Please enter your choice: ${ENDCOLOR}")" choice

    case $choice in
        1)  pkg_install ; service_nftables ; sleep 1; clear; nftwizard; reload_nft ; continue ;;
        2)  add_ip_withlist; sleep 1; continue ;;        
        3)  add_ip_block_list; sleep 1 ; continue ;;
        4)  display_rules; continue ;;                                        
        5)  add_rule ; continue ;;                           
        6)  delete_rule ; continue ;;                        
        7)  flush_all_rules ; sleep 1 ; continue ;;              
        8)  save_nftables_rules; sleep 1; service_nftables; continue;;  
        9)  ddos; continue ;;                                                  
        10) add_port_withlist; sleep 1; reload_nft ; continue ;;              
        11) load_rules_file; sleep 1; reload_nft ;continue ;;
        12) block_port; sleep 1 ;reload_nft ; continue ;;
        13) sleep 1; clear; echo "Exiting..."; exit ;;
        *) echo -e "${RED}Invalid option, please try again.${ENDCOLOR}" ;;
    esac

    sleep 1
done

