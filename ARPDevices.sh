#!/bin/sh
VER="v01.03"
#======================================================================================================= © 2016-2019 Martineau, v1.03
#
# Check if ARP cache is valid for expected devices.
#
#     ARPDevices
#                  List ARP cache
#                  e.g.
#                       Warning may take upto 60secs to resolve ARP
#                       10.88.8.12  c4:xx:xx:xx:xx:xx   TL-SG2008-Bed1  (TL-SG2008-Bed1.Martineau.lan)
#                       10.88.8.100 <incomplete>        N/A             (EeeBox.Martineau.lan)
#                       <snip>
#
#                       WAN.ISP.xxx.xxx    28:xx:xx:xx:xx:xx   N/A     (WAN_ISP_provider)
#
#                       Records CNT=19 TAGGED=18
#
#                       .......took 3 seconds
#
#     ARPDevices   refresh
#                  If '/jffs/scripts/Reset_NVRAM-DHCPstatic.sh' exists; contents will be used as a ping target(s)
#                  otherwise
#                  NVRAM variable dhcp_staticlist will be used as a ping target(s)
#
# To clear ARP cache use:
#		ip neigh flush all 
#

#
Say(){
   echo -e $$ $@ | logger -st "($(basename $0))"
}
SayT(){
   echo -e $$ $@ | logger -t "($(basename $0))"
}

# Print between line beginning with'#==' to first blank line inclusive
ShowHelp() {
    /usr/bin/awk '/^#==/{f=1} f{print; if (!NF) exit}' $0
}
# Function Parse(String delimiter(s) variable_names)
Parse() {
    #
    #   Parse       "Word1,Word2|Word3" ",|" VAR1 VAR2 REST
    #               (Effectivley executes VAR1="Word1";VAR2="Word2";REST="Word3")

    local string IFS

    TEXT="$1"
    IFS="$2"
    shift 2
    read -r -- "$@" <<EOF
$TEXT
EOF
}

ANSIColours () {

    cRESET="\e[0m";cBLA="\e[30m";cRED="\e[31m";cGRE="\e[32m";cYEL="\e[33m";cBLU="\e[34m";cMAG="\e[35m";cCYA="\e[36m";cGRA="\e[37m"
    cBGRA="\e[90m";cBRED="\e[91m";cBGRE="\e[92m";cBYEL="\e[93m";cBBLU="\e[94m";cBMAG="\e[95m";cBCYA="\e[96m";cBWHT="\e[97m"
    aBOLD="\e[1m";aDIM="\e[2m";aUNDER="\e[4m";aBLINK="\e[5m";aREVERSE="\e[7m"
    cRED_="\e[41m";cGRE_="\e[42m"

}

Main() { true; }			# Syntax that is Atom Shellchecker compatible!

ANSIColours

# Provide assistance
if [ "$1" = "-h" ] || [ "$1" = "help" ]; then
   ShowHelp                                                     # Show help
   exit 0
fi

FIRMWARE=$(echo $(nvram get buildno) | awk 'BEGIN { FS = "." } {printf("%03d%02d",$1,$2)}')

HACK=0                                                      # Tacky!.... variables not available outside of do loop????

LANIPADDR=$(nvram get lan_ipaddr)
LAN_SUBNET=${LANIPADDR%.*}
OCTET1=${LANIPADDR%%.*}										# v1.02

NVRAM_FN="Reset_NVRAM-DHCPstatic.sh"                        # Basically use custom list to check all devices..

# Perform a PING refresh of the ARP cache
if [ "$1" == "refresh" ];then
    if [ ! -f "$NVRAM_FN" ];then
        # Assumes I haven't kept 'Reset_NVRAM-DHCPstatic.sh' up to date! ;-)
        NVRAM_FN="/tmp/NVRAM_dhcp"          # Use the NVRAM variable to check all DHCP reserved devices..
        # Ensure the $FN contains records
        nvram get dhcp_staticlist | sed 's/</\n</g' > $NVRAM_FN

    fi
        CNT=$(grep -v "^#" "$NVRAM_FN" | grep -Fc "<" )
        echo -e $cBCYA"\n\t"$VER "PING ARP refresh: may take up to" $CNT "secs if ALL are not ONLINE! (1 second per IP) using '$NVRAM_FN'\n"

        CNT=
        start=`date +%s`

        for IP in $(grep -v "^#" "$NVRAM_FN" | grep -F "<" | awk ' BEGIN {FS=">" } {print $2}')
            do
                COLOR=$cBGRE
                if [ -n "$(echo $IP | grep LAN_SUBNET)" ];then
                    IP=${LAN_SUBNET}.${IP##*\.}
                fi
                ping -q -c1 -w1 $IP 2>&1 >/dev/null
                if [ $? -eq 1 ];then
                    COLOR=$cBRED
                fi
                echo -en ${COLOR}$IP"\t"
            done

        end=`date +%s`
        difftime=$((end-start))
        start=`date +%s`
        echo -e $cBYEL"\n\n\t.......took $(($difftime % 60)) seconds\n"$cRESET

        echo -e $cRESET
fi

if [ -z "$1" ];then
    echo -e $cBYEL"\n\t"$VER "ARP cache report - Warning may take upto 60secs to resolve ARP\n\n"
else
    echo -e $cBCYA"\n\t"$VER "ARP cache report"
fi

echo -e $cBMAG

start=`date +%s`

#
#       arp -a
#           LIFX-Reading.Martineau.lan (10.88.8.31) at d0:xx:xx:xx:xx:xx [ether]  on br0
#
#       ip neigh
#           10.88.8.31 dev br0 lladdr d0:xx:xx:xx:xx:xx REACHABLE
#
#       cat /proc/net/arp
#           10.88.8.31       0x1         0x2         d0:xx:xx:xx:xx:xx     *        br0

# Check if counts match
if [ -f /etc/hosts.dnsmasq ];then
	if [ $(wc -l  </etc/hosts.dnsmasq) -ne $(grep -cE "^dhcp-host" /etc/dnsmasq.conf) ];then
		echo -e $cRED"\n\t\a**Warning: Number of '/etc/hosts.dnsmasq' entries does not match number of 'dhcp-host' entries in '/etc/dnsmasq.conf'"$cRESET
	fi
fi

arp -a | awk '{print $2","$4","$1}' | tr -d '()' | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 | while read ARP_DEVICE
do
    if [ -z $CNT ];then
        CNT=0;TAGGED=0
    fi

    # Match MAC with what we have in /etc/ethers -> /etc/hosts.dnsmasq to get a valid description
    # Device must be defined in DHCP table :-(
    Parse $ARP_DEVICE "," ARP_IP ARP_MAC ARP_DESC
	if [ $CNT -eq 0 ];then
		LASTOCTECT1=$(echo $ARP_IP | awk ' FS="." {print $1}')
	fi
    DESC="N/A\t"
    if [ "$ARP_MAC" != "<incomplete>" ];then
        if [ "$ARP_DESC" != "?" ];then
            TAGGED=$((TAGGED+1))
        fi
        FN="/etc/ethers"
        if [ $FIRMWARE -ge 38201 ];then
            # /etc/ethers no longer exists/used
            # Instead /etc/dnsmasq.conf contains
            #         dhcp-host=00:xx:xx:xx:xx:xx,10.88.8.254
            FN="/etc/dnsmasq.conf"
				if [ "$(grep -i "$ARP_MAC" "$FN" | awk ' FS="," {print $2}' | wc -l)" -gt 1 ];then
					echo -e $cRED"\a*Duplicate*\t"$ARP_MAC"\tFOUND in '"$FN"' ???; Following description may be INVALID"$cBMAG
				fi
				if [ -n "$(grep -i "$ARP_MAC" "$FN" | awk ' FS="," {print $2}')" ];then
					DESC=$(grep -i "$(grep -i "$ARP_MAC" "$FN" | awk ' FS=","{print $2}')\b" /etc/hosts.dnsmasq | awk '{print $2}')
						if [ "${#DESC}" -lt 8 ];then
							DESC=$DESC"\t"                  # Cosmetic tabular formatting!
						fi
				else
					if [ "$DESC" == "N/A\t" ];then
						[ "$ARP_IP" == "$(nvram get wan0_gateway)" ] && { DESC="WAN0 Gateway"; LINECOLOR=$cBYEL; }
						
						[ -z "$DESC" ] && DESC="N/A\t"
					fi
				fi
        else
            if [ -n $(grep -i "$ARP_MAC" "$FN" | awk '{print $2}') ];then
                DESC=$(grep -i "$(grep -i "$ARP_MAC" "$FN" | awk '{print $2}')\b" /etc/hosts.dnsmasq | awk '{print $2}')
                if [ -z "$DESC" ];then
                    DESC="N/A\t"
                else
                    if [ "${#DESC}" -lt 8 ];then
                        DESC=$DESC"\t"                  # Cosmetic tabular formatting!
                    fi
                fi
            fi
        fi
    else
        DESC="\tN/A\t"
    fi

    CNT=$((CNT+1))

	# If the current subnet prefix has changed assumed it is the WAN, so print summary
	if [ "$LASTOCTECT1" != "$(echo $ARP_IP | awk ' FS="." {print $1}')" ];then
		if [ -n "$(echo $(nvram get wans_dualwan) | grep "none")" ];then
			echo -e $cBYEL
			HACK=1                                                  # Tacky!.... variables not available outside of do loop????
		else
			printf "\n"
		fi
	fi
    echo -e ${LINECOLOR}$ARP_IP"\t"$ARP_MAC"\t"$DESC"\t("$ARP_DESC")"
	LINECOLOR=$cBMAG
	LASTOCTECT1=$(echo "$ARP_IP" | awk ' FS="." {print $1}')
    if [ $HACK -eq 1 ];then
        echo -e "\nRecords CNT="$CNT "TAGGED="$TAGGED             # Tacky!.... variables not available outside of do loop????
    fi
    DESC=
done

end=`date +%s`
difftime=$((end-start))

echo -e $cBYEL"\n\t.......took $(($difftime % 60)) seconds\n"$cRESET
