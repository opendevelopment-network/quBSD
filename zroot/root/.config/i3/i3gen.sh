#!/bin/bash

# Uese i3gen.conf to generate i3 config lines

config='/root/.config/i3/config'
setup='/root/.config/i3/i3gen.conf'
jailselect=$(egrep '^bindsym .* mode' $setup)
jaillist=$(sed -n '/JAIL[[:blank:]]*GROUP[[:blank:]]*SYM1/,/ALIAS[[:blank:]]*SYM[[:blank:]]*COMMAND/p' \
												$setup | sed '/^$/d' | egrep -v "^#")
hostcommands=$(sed '1,/ALIAS[[:blank:]]*SYM[[:blank:]]/d'  $setup | sed '/^$/d' | egrep -v "^#" \
												| sed 's/#.*//g' | sed 's/[[:blank:]]*$//g')
wc=$(echo "$jaillist" | wc -l)

initialize_config() {			
	sed -i '' -e '/AUTO GENERATED MODES/,$d' "$config"
	printf "%b" "##  AUTO GENERATED MODES  ##\n" \
	       "##  Edit i3gen.conf and run i3gen.sh to make changes  ##\n\n\n"  >> "$config"
}

jailselect() { 			
# Creates the first level binding mode
	printf "%b" "##  FIRST LEVEL BINDING MODE  ##" "\n"  >> "$config"
	printf "%b" "\n" "$jailselect" "\n\n"  >> "$config"
	printf "%b" "mode ${jailselect#bindsym * mode } {"  >>  "$config"

	local loop="1"
	while [ "$loop" -le "$wc" ] ; do 
		local jail=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $1}')
		local sym=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $3}')
		local group=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $2}')
		local check=$(grep "bindsym $sym mode \"$group\"" "$config")

		## Jails without a grouped bindsym get directly mapped at the first level
		if [ "$group" = "none" -o "$group" = "-" ]; then			
			printf "%b" "\n\t" "bindsym ${sym} mode \"${jail}\""  >> "$config"

		## If not existing, create bindsym for second level group binding mode
		elif [ -z "$check" ] ; then 			
			printf "%b" "\n\t" "bindsym ${sym} mode \"${group}\""  >> "$config"
		fi
		loop=$(( loop + 1 ))
	done

	printf "%b" "\n\t" "bindsym Return mode \"default\"" "\n\t" \
					"bindsym Escape mode \"default\"" "\n" "}\n\n"  >> "$config"
}

groupmode() {					
# Prints the header, close, and escapes for each 2nd level binding mode group
	printf "%b" "##  SECOND LEVEL, GROUPED MODE KEYBINDINGS  ##" "\n\n"  >> "$config"
	local loop="1"

	while [ "$loop" -le "$wc" ] ; do 
		local group=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $2}')
		local check=$(grep "mode \"$group\" {" ""$config"")

		if [ "$group" != "-" -a "$group" != "none" -a -z "$check" ]; then   	
			printf "%b" "mode \"$group\" {" "\n"  >> "$config"
			printf "%b" "\t" "bindsym Return mode \"default\"" "\n"   >> "$config"
			printf "%b" "\t" "bindsym Escape mode \"default\"" "\n}\n\n"   >> "$config"
		fi		
		loop=$(( loop + 1 ))
	done
}

group_populate() {				
# Populates the body of each group mode with jail mode mappings
	local loop="1"
	local newln=$(echo -e "\n")

	while [ "$loop" -le "$wc" ] ; do 
		local jail=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $1}')
		local sym=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $4}')
		local group=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $2}')
		local check=$(grep "mode \"$group\" {" ""$config"")
		local newln=$(printf "%b" " \\" "\n" "\t" "bindsym $sym mode \"$jail\"")

		if [ "$group" != "-" -a "$group" != "none" ]; then	
			sed -i '' -e "/$check/ s/$/$newln/" $config	
		fi
		loop=$(( loop + 1 ))
	done
}

jailgen() {
# Generates the actual exec command lines for each jail mode
	printf "%b" "##  JAIL KEYBINDINGS FOR EXEC COMMANDS  ##" "\n\n"  >> "$config"
	local loop="1"

	while [ "$loop" -le "$wc" ] ; do 
		local jail=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $1}')
		local progs=$(echo "$jaillist" | sed -n ${loop}p | awk '{print $5}' | sed 's/,/ /g')
		printf "%b" "mode \"$jail\" {"  >>  "$config"

		## Searches for alias, and replaces with full command
		for p in $progs; do
			sym=$(echo "$hostcommands" | egrep "^${p}" | awk '{print $2}')
			passed_command=$(echo "$hostcommands" | egrep "^${p}" \
			| sed "s/^[^[:blank:]]*[[:blank:]]*[^[:blank:]]*[[:blank:]]*//" | sed "s,\$jail,${jail},") 
		
			if [ -n "$sym" ]; then	
				printf "%b" "\n\tbindsym $sym exec $passed_command , mode \"default\"" >> "$config"; else
				printf "%b" "\n\t\t## COMMAND \"$p\" NOT FOUND IN i3gen.conf file"  >> "$config"
			fi
		done

	printf "%b" "\n\tbindsym Return mode \"default\"" \
			"\n\tbindsym Escape mode \"default\"" "\n}\n\n"  >> "$config"
	loop=$(( loop + 1 ))
	done
}

main() {
	initialize_config
	jailselect
	groupmode	
	group_populate
	jailgen
}

main
