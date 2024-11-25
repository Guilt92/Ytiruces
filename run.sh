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
    echo "==================================="
    echo "         iptables Manager          "
    echo "==================================="
    echo "1. Display current rules"
    echo "2. Add a new rule"
    echo "3. Delete a rule"
    echo "4. Flush all rules"
    echo "5. Save rules to file"
    echo "6. Load rules from file"
    echo "7. Exit"
    echo "==================================="
    }



Display_rules(){
    echo "Current Iptables Rules: "
    sudo iptables -L -n -v --line-numbers
}






