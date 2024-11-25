#!/bin/bash 

# Script: Manage iptables rules
# Author: Your Name
# Date: $(date +"%Y-%m-%d")


ORANGE=$(echo -ne '\e[38;5;214m')
BLUE=$(echo -ne '\e[94m')
RED=$(echo -ne '\e[31m')
GREEN=$(echo -ne '\e[32m')
ENDCOLOR=$(echo -ne '\e[0m')
YELLOW=$(echo -ne '\033[0;33m')

check_user_root()
{
	if [ "$EUID" -ne 0 ];then 
		echo -e "${RED}This script must be run as root. Please switch to the root user and try again.${ENDCOLOR}"
		exit 1
	fi
}



show_menu(){
    echo -e "${BLUE}===================================${ENDCOLOR}"
    echo -e "${BLUE}         iptables Manager          ${ENDCOLOR}"
    echo -e "${BLUE}===================================${ENDCOLOR}"
    echo -e "${BLUE}1. Display current rules${ENDCOLOR}"
    echo -e "${BLUE}2. Add a new rule${ENDCOLOR}"
    echo -e "${BLUE}3. Delete a rule${ENDCOLOR}"
    echo -e "${BLUE}4. Flush all rules${ENDCOLOR}"
    echo -e "${BLUE}5. Save rules to file${ENDCOLOR}"
    echo -e "${BLUE}6. Load rules from file${ENDCOLOR}"
    echo -e "${RED}7. Exit${ENDCOLOR}"
    echo -e "${BLUE}===================================${ENDCOLOR}"
    }



Display_rules(){
    echo "Current Iptables Rules: "
    sudo iptables -L -n -v --line-numbers
}





add rule(){

    read -p "${BLUE} Entrt Chain  (INPUT / OUTPUT /  FORWARD)  ${ENDCOLOR}" chain
    read -p "${BLUE} Enter protocol (tcp/udp/icmp): ${ENDCOLOR} " protocol
    read -p "${BLUE} Enter source IP (or 0.0.0.0/0 for any): ${ENDCOLOR} " source
    read -p "${BLUE} Enter destination IP (or 0.0.0.0/0 for any): ${ENDCOLOR} " destination
    read -p "${BLUE} Enter destination port (or leave empty for none): ${ENDCOLOR} " port
    read -p "${BLUE} Enter action (ACCEPT/DROP): ${ENDCOLOR} " action

    if [ -z "$port" ]; then
        sudo iptables -A $chain -p $protocol -s $source -d $destination -j $action
    else
        sudo iptables -A $chain -p $protocol -s $source -d $destination --dport $port -j $action
    fi
    echo "{GREEN} Rule added successfully!${ENDCOLOR}"

}





delete_rule() {
    display_rules
    read -p "${BLUE}Enter chain (INPUT/OUTPUT/FORWARD):${ENDCOLOR} " chain
    read -p "${BLUE}Enter rule number to delete: ${ENDCOLOR}" rule_number
    sudo iptables -D $chain $rule_number
    echo "{$GREEN}Rule deleted successfully!${ENDCOLOR}"
}



flush_rules() {
    read -p "${BLUE}Are you sure you want to flush all rules? (y/n): ${ENDCOLOR}" confirm
    if [[ "$confirm" == "y" ]]; then
        sudo iptables -F
        echo "${GREEN}All rules flushed!${ENDCOLOR}"
    else
        echo "${RED} Operation cancelled. ${ENDCOLOR}"
    fi
}


save_rules() {
    read -p "Enter file name to save rules: ${BLUE} " filename
    sudo iptables-save > $filename
    echo "${ORANGE}Rules saved to $filename ${ENDCOLOR}"
}




load_rules() {
    read -p "${BLUE} Enter file name to load rules from: ${ENDCOLOR}" filename
    if [[ -f $filename ]]; then
        sudo iptables-restore < $filename
        echo " ${GREEN} Rules loaded from $filename ${ENDCOLOR}"
    else
        echo "${RED}File not found!${ENDCOLOR}"
    fi
}


while true; do
    show_menu
    read -p "${ORANGE}Choose an option: ${ENDCOLOR}" choice
    case $choice in
        1) display_rules ;;
        2) add_rule ;;
        3) delete_rule ;;
        4) flush_rules ;;
        5) save_rules ;;
        6) load_rules ;;
        7) echo "Exiting..."; break ;;
        *) echo "${RED}Invalid option! Please try again. ${ENDCOLOR}" ;;
    esac
done




