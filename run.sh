#!/bin/bash 

ORANGE=$(echo -ne '\e[38;5;214m')
BLUE=$(echo -ne '\e[94m')
RED=$(echo -ne '\e[31m')
GREEN=$(echo -ne '\e[32m')
ENDCOLOR=$(echo -ne '\e[0m')
YELLOW=$(echo -ne '\033[0;33m')

check_user_root

show_menu(){
    echo -e "${BLUE}===================================${ENDCOLOR}"
    echo -e "${BLUE}         nftables Manager          ${ENDCOLOR}"
    echo -e "${BLUE}===================================${ENDCOLOR}"
    echo -e "${BLUE}1. Display current rules${ENDCOLOR}"
    echo -e "${BLUE}2. Add a new rule${ENDCOLOR}"
    echo -e "${BLUE}3. Delete a rule${ENDCOLOR}"
    echo -e "${BLUE}4. Flush all rules${ENDCOLOR}"
    echo -e "${BLUE}5. Save rules to file${ENDCOLOR}"
    echo -e "${BLUE}6. DDOS_plus${ENDCOLOR}"
    echo -e "${BLUE}7. reset_nftables${ENDCOLOR} ${RED} (Risky)  ${ENDCOLOR}"
    echo -e "${BLUE}8. Load rules from file${ENDCOLOR}"
    echo -e "${RED}9. Exit${ENDCOLOR}"
    echo -e "${BLUE}===================================${ENDCOLOR}"
}

check_user_root(){
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}This script must be run as root. Please switch to the root user and try again.${ENDCOLOR}"
        exit 1
    fi
}

Display_rules(){
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
    sudo nft add chain ip mangle output { type route hook output priority -150 \; }

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

add_port(){

    check_user_root
    read -p "${BLUE}Enter prot: ${ENDCOLOR}" prot
    sudo nft add rule inet filter input tcp dport $port ct state new,established accept
    sudo nft add rule inet filter output tcp sport $port ct state established accept
    
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
        sudo nft add rule inet filter input tcp dport 80 ct state new,established accept  
        sudo nft add rule inet filter input tcp dport 443 ct state new,established accept
        sudo nft add rule inet filter input udp dport 53 ct state new,established accept  
        sudo nft add rule inet filter input tcp dport 53 ct state new,established accept  

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

while true
do
    PS3='Please enter your choice: '
    options=("display_rules" "add_rule" "delete_rule" "flush_rules" "save_nftables_rules" "DDos_plus" "reset_nftables" "load_rules" "Exit")
    select opt in "${options[@]}"
    do
        case $opt in
            "display_rules")
                Display_rules
                break
                ;;
            "add_rule")
                add_rule
                break
                ;;
            "delete_rule")
                delete_rule
                break
                ;;
            "flush_rules")
                flush_rules
                break
                ;;
            "save_nftables_rules")
                save_nftables_rules
                break
                ;;
            "DDos_plus")
                
                break
                ;;
            "reset_nftables")
                
                break
                ;;
            "load_rules")
                load_rules
                break
                ;;
            "Exit")
                echo -e "${RED}Exiting...${ENDCOLOR}"
                exit
                ;;
            *)
                echo "Invalid option, please try again."
                ;;
        esac
    done
done
