#!/bin/sh


# Source configuration file.
. ./8006a1config.sh


# Configure interal host for standalone firewall architecture.
internal_host() {
    ifconfig $i_external_interface down
    ifconfig $i_internal_interface $i_internal_ip up
    route add default gw $e_internal_ip
    route -n

    printf "Internal host config complete."
}


# Configure firewall host for standalone firewall architecture.
firewall_host() {
    ifconfig $e_internal_interface $e_internal_ip up
    echo "1" >/proc/sys/net/ipv4/ip_forward
    route add -net $e_external_subnet gw $e_external_ip
    route add -net $e_internal_subnet gw $e_internal_ip

    route -n
    iptables -t nat -L
    printf "Firewall host config complete."
}

# Configure interal host for standalone firewall architecture.
remote_host() {
    route add -net $e_internal_subnet gw $e_external_ip
    route -n

    printf "Remote host config complete."
}


resolvconf_fix() {
    rm /etc/resolv.conf
    touch /etc/resolv.conf
    echo "nameserver 8.8.8.8" >/etc/resolv.conf
    printf "resolvconf_fix complete."
}


flush_iptables() {
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X
    iptables -t nat -X
    iptables -t mangle -X

    printf "flush_iptables complete."
}


tcp_chain_function() {
    # Accept TCP packets to existing connections on allowed ports
    iptables -N tcp_allowed
    iptables -A tcp_allowed -p tcp -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A tcp_allowed -p tcp --syn -m state --state NEW -j ACCEPT
    iptables -A tcp_allowed -p tcp -j REJECT --reject-with tcp-reset


    # TCP filter user defined chain
    iptables -N tcp_filter
    # Reject bad tcp packets that are new SYN,ACK with reset
    iptables -A tcp_filter -p tcp --tcp-flags SYN,ACK SYN,ACK -m state --state NEW -j REJECT --reject-with tcp-reset
    # Drop all SYN and FIN bit packets
    iptables -A tcp_filter -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    # Drop bad tcp packets that are new non-SYN packets
    #iptables -A tcp_filter -p TCP ! --syn -m state --state NEW -j REJECT --reject-with tcp-reset

    # Add allowed TCP ports from config
    for port_num in ${tcp_allowed_ports_array[*]}
    do
        iptables -A tcp_filter -p tcp --dport $port_num -j tcp_allowed
        iptables -A tcp_filter -p tcp --sport $port_num -j tcp_allowed
    done

    # Reject any TCP packets coming the wrong way or falls through rules
    iptables -A tcp_filter -p tcp -j REJECT --reject-with tcp-reset

}

udp_chain_function() {
    # Add allowed UDP ports from config
    iptables -N udp_filter
    for port_num in ${udp_allowed_ports_array[*]}
    do
        iptables -A udp_filter -p udp --dport $port_num -m state --state NEW,ESTABLISHED -j ACCEPT
        iptables -A udp_filter -p udp --sport $port_num -m state --state NEW,ESTABLISHED -j ACCEPT
    done

    iptables -A udp_filter -p udp -j DROP
}


icmp_chain_function() {
    # Add allowed ICMP types from config
    iptables -N icmp_filter
    for icmp_type in ${icmp_allowed_types_array[*]}
    do
        iptables -A icmp_filter -p icmp --icmp-type $icmp_type -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
    done

    iptables -A icmp_filter -p icmp -j DROP
}


# Configure firewall rules on firewall host.
firewall_host_rules() {

    # Set default policies to drop if not matching any rules
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP


    # Masquerade internal subnet packets to firewall host
    iptables -A POSTROUTING -t nat -s $e_internal_subnet -o $e_external_interface -j MASQUERADE


    # Block all telnet packets
    iptables -A INPUT -p tcp --sport 23 -j DROP
    iptables -A FORWARD -p tcp --dport 23 -j DROP
    iptables -A OUTPUT -p tcp --dport 23 -j DROP



    # Drop inbound traffic to port 80 from sport less than 1024
    iptables -A INPUT -p tcp --sport 0:1023 --dport 80 -j DROP
    iptables -A FORWARD -p tcp --sport 0:1023 --dport 80 -j DROP

    # Drop inbound traffic of sport 0 and outbound of dport 0
    iptables -A INPUT -p tcp --sport 0 -j DROP
    iptables -A OUTPUT -p tcp --dport 0 -j DROP
    iptables -A FORWARD -p tcp --dport 0 -j DROP
    iptables -A FORWARD -p tcp --sport 0 -j DROP


    # Drop all external packets with source address matching internal network
    iptables -A INPUT -s $e_internal_subnet ! -i $e_internal_interface -j DROP
    iptables -A FORWARD -s $e_internal_subnet ! -i $e_internal_interface -j DROP


    # Allow www (http, https) and dns packets outbound
    # Note, inbound http, https, dns, caught with INPUT state ESTABLISHED rule futher down
    for port_num in ${tcp_allowed_ports_array[*]}
    do
        if [ "$port_num" = "80" ]
        then
            # Allow http packets outbound
            iptables -A OUTPUT -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
            iptables -A FORWARD -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
        fi
        if [ "$port_num" = "443" ]
        then
            # Allow https packets outbound
            iptables -A OUTPUT -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
            iptables -A FORWARD -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
        fi
        if [ "$port_num" = "53" ]
        then
            # Allow dns packets outbound
            iptables -A OUTPUT -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
            iptables -A OUTPUT -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
            iptables -A FORWARD -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
            iptables -A FORWARD -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
        fi
    done


    # SSH rules
    # Note, inbound http, https, dns, caught with INPUT state ESTABLISHED rule futher down
    for port_num in ${tcp_allowed_ports_array[*]}
    do
        if [ "$port_num" = "22" ]
        then
            # Allow SSH forwarding
            iptables -A FORWARD --out-interface $e_external_interface -p tcp --destination-port 22 -m state --state NEW -j ACCEPT
            iptables -A FORWARD --out-interface $e_external_interface -p tcp ! --syn --destination-port 22 -j ACCEPT
            iptables -A FORWARD --in-interface $e_external_interface -p tcp --syn --destination-port 22 -j ACCEPT

            # Only allow firewall SSH outbound
            iptables -A OUTPUT -p tcp --destination-port 22 -m state --state NEW -j ACCEPT
            iptables -A OUTPUT -p tcp ! --syn --destination-port 22 -j ACCEPT
            # Accept packets to firewall that packets that are part of established or related connections.
            iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        fi
    done


    # Drop packets with an invalid state
    #iptables -A INPUT -m state --state INVALID -j DROP

    # TCP user defined rules
    tcp_chain_function
    udp_chain_function
    icmp_chain_function

    iptables -A FORWARD -p tcp -j tcp_filter
    iptables -A FORWARD -p udp -j udp_filter
    iptables -A FORWARD -p icmp -j icmp_filter


     # SSH and FTP minimum delay and maximum throughput page 31
    iptables -A PREROUTING -t mangle -p tcp --sport ssh -j TOS --set-tos Minimize-Delay
    iptables -A PREROUTING -t mangle -p tcp --sport ftp -j TOS --set-tos Minimize-Delay
    iptables -A PREROUTING -t mangle -p tcp --sport ftp -j TOS --set-tos Maximize-throughput



    # Forward packets that are part of established or related connections.
    # iptables -A FORWARD -i $e_external_interface -o $e_internal_interface -m state --state RELATED,ESTABLISHED -j ACCEPT
    # Forward all internal packets to external interface
    # iptables -A FORWARD -i $e_internal_interface -o $e_external_interface -j ACCEPT

    # Accepts packets on localhost
    # iptables -A INPUT -i lo -j ACCEPT



    printf "firewall_host_rules complete."
}


while true
do
	# clear
	 cat << 'MENU'
 	1................................... Configure Interal Host
 	2................................... Configure Remote Host
 	3................................... Configure Firewall Host
 	4................................... Configure Firewall Host Rules
 	5................................... /etc/resolv.conf fix
 	6................................... Flush iptables
 	0................................... Quit
MENU
	echo -n '           Input number for choice, then Return >'
	read number rest
	case ${number} in
		[1])	internal_host ;;
		[2])	remote_host ;;
		[3])	firewall_host ;;
		[4])	firewall_host_rules	;;
        [5])	resolvconf_fix	;;
        [6])	flush_iptables	;;
		[0])	exit	;;
		*)	echo; echo Unrecognized choice: ${number} ;;
	esac
	echo; echo -n ' Press Enter to continue.....'
	read rest
done


