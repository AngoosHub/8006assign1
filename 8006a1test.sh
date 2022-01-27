#!/bin/sh


# Source configuration file.
. ./8006a1config.sh



external_test_function() {
    dnf install hping3 -y

    # Telnet test
    # ping from external machine, should fail
    echo "\n================================================================================" &>> test_output.txt
    echo "Telnet Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -c 3 $remote_ssh_server_ip -S -p 23 &>> test_output.txt


    # Drop inbound dport 80 from sport less than 1024
    # hping3 from external machine, 1023 not dropped, rejected/reset?
    echo "\n================================================================================" &>> test_output.txt
    echo "Dport 80, Sport < 1024 Test: Sport 1023 PASS if 100% packet losses." &>> test_output.txt
    hping3 -c 3 $i_internal_ip -A -s 1023 -k -p 80 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Dport 80, Sport < 1024 Test: Sport 1024 PASS if 3 packets received." &>> test_output.txt
    hping3 -c 3 $i_internal_ip -A -s 1024 -k -p 80 &>> test_output.txt


    # Drop port 0 packets
    # hping3 from external machine, should fail
    echo "\n================================================================================" &>> test_output.txt
    echo "Port 0 Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -c 3 $i_internal_ip -S -s 0 -k -p 0 &>> test_output.txt

    # Drop external packet spoofing as internal subnet ip
    # both on external machine, first should fail dropped, second maybe pass?
    echo "\n================================================================================" &>> test_output.txt
    echo "Spoofing Test: External IP, PASS if 100% packet losses." &>> test_output.txt
    hping3 -c 3 $e_internal_ip -a $i_internal_ip -S -s 2000 -k -p 80 &>> test_output.txt


    # Accept packets for http, https, dns
    # (TEST) can open browser in internal machine
    echo "\n================================================================================" &>> test_output.txt
    echo "www Test: PASS if 3 packets received (1 dport 80, 1 dport 443, 1 dport 53)." &>> test_output.txt
    hping3 -V -c 1 $i_internal_ip -S -s 2000 -k -p 80 &>> test_output.txt
    hping3 -V -c 1 $i_internal_ip -S -s 2000 -k -p 443 &>> test_output.txt
    hping3 -V -c 1 $i_internal_ip -S -s 2000 -k -p 53 &>> test_output.txt


    # SSH test
    # (TEST) ssh from internal machine to external machine should work
    # (TEST) ssh from external to internal, works
    echo "\n================================================================================" &>> test_output.txt
    echo "ssh Test: PASS if 3 packets received." &>> test_output.txt
    hping3 -V -c 3 $i_internal_ip -S -s 22 -k -p 22 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "ssh Test: (to firewall) PASS if 100% packet losses." &>> test_output.txt
    hping3 -V -c 3 $e_internal_ip -S -s 22 -k -p 22 &>> test_output.txt


    # TCP Chain test
    # this tcp works, gets RST,ACKs back, passes
    echo "\n================================================================================" &>> test_output.txt
    echo "TCP Test: PASS if 3 packets received." &>> test_output.txt
    hping3 -V -c 3 $i_internal_ip -S -s 200 -k -p 8000 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "TCP Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -V -c 3 $i_internal_ip -S -s 200 -k -p 8001 &>> test_output.txt


    # should drop SIN,FIN packets, no reply, passes
    echo "\n================================================================================" &>> test_output.txt
    echo "Syn & Fin Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -V -c 3 $i_internal_ip -S -F -s 200 -p 8000 &>> test_output.txt


    # UDP chain test
    echo "\n================================================================================" &>> test_output.txt
    echo "Udp Test: Dport 8000, PASS if 3 packets received dest unreachable." &>> test_output.txt
    hping3 -V -c 3 -2 $i_internal_ip -p 8000 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Udp Test: Dport 8001, PASS if packet drop/lost." &>> test_output.txt
    hping3 -V -c 3 -2 $i_internal_ip -p 8001 &>> test_output.txt


    # ICMP chain test
    echo "\n================================================================================" &>> test_output.txt
    echo "Icmp Test: type 8, PASS if 3 packets received." &>> test_output.txt
    hping3 -V -c 3 -1 $i_internal_ip -C 8 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Icmp Test: type 13, PASS if packet drop/lost." &>> test_output.txt
    hping3 -V -c 3 -1 $i_internal_ip -C 13 &>> test_output.txt


    # mangle test, show the mangle table count increased
    echo "\n================================================================================" &>> test_output.txt
    echo "Mangle Test: ftp, PASS if mangle table counter is 3." &>> test_output.txt
    hping3 -V -c 3 $i_internal_ip -S -p 21 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Mangle Test: ssh, PASS if mangle table counter is 3." &>> test_output.txt
    hping3 -V -c 3 $i_internal_ip -S -p 22 &>> test_output.txt

    printf "END TEST"
    echo "END TEST" &>> test_output.txt

}


internal_test_function() {
    dnf install hping3 -y

    # Telnet test
    # ping from external machine, should fail
    echo "\n================================================================================" &>> test_output.txt
    echo "Telnet Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -c 3 $remote_ssh_server_ip -S -p 23 &>> test_output.txt


    # Drop port 0 packets
    # hping3 from external machine, should fail
    echo "\n================================================================================" &>> test_output.txt
    echo "Port 0 Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -c 3 $remote_ssh_server_ip -S -s 0 -k -p 0 &>> test_output.txt



    # Accept packets for http, https, dns
    # (TEST) can open browser in internal machine
    echo "\n================================================================================" &>> test_output.txt
    echo "www Test: PASS if 3 packets received (1 dport 80, 1 dport 443, 1 dport 53)." &>> test_output.txt
    hping3 -V -c 1 $remote_ssh_server_ip -S -s 2000 -k -p 80 &>> test_output.txt
    hping3 -V -c 1 $remote_ssh_server_ip -S -s 2000 -k -p 443 &>> test_output.txt
    hping3 -V -c 1 $remote_ssh_server_ip -S -s 2000 -k -p 53 &>> test_output.txt


    # SSH test
    # (TEST) ssh from internal machine to external machine should work
    # (TEST) ssh from external to internal, works
    echo "\n================================================================================" &>> test_output.txt
    echo "ssh Test: PASS if 3 packets received." &>> test_output.txt
    hping3 -V -c 3 $remote_ssh_server_ip -S -s 22 -k -p 22 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "ssh Test: (to firewall) PASS if 100% packet losses." &>> test_output.txt
    hping3 -V -c 3 $e_internal_ip -S -s 22 -k -p 22 &>> test_output.txt


    # TCP Chain test
    # this tcp works, gets RST,ACKs back, passes
    echo "\n================================================================================" &>> test_output.txt
    echo "TCP Test: PASS if 3 packets received." &>> test_output.txt
    hping3 -V -c 3 $remote_ssh_server_ip -S -s 200 -k -p 8000 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "TCP Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -V -c 3 $remote_ssh_server_ip -S -s 200 -k -p 8001 &>> test_output.txt


    # should drop SIN,FIN packets, no reply, passes
    echo "\n================================================================================" &>> test_output.txt
    echo "Syn & Fin Test: PASS if 100% packet losses." &>> test_output.txt
    hping3 -V -c 3 $remote_ssh_server_ip -S -F -s 200 -p 8000 &>> test_output.txt


    # UDP chain test
    echo "\n================================================================================" &>> test_output.txt
    echo "Udp Test: Dport 8000, PASS if 3 packets received dest unreachable." &>> test_output.txt
    hping3 -V -c 3 -2 $remote_ssh_server_ip -p 8000 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Udp Test: Dport 8001, PASS if packet drop/lost." &>> test_output.txt
    hping3 -V -c 3 -2 $remote_ssh_server_ip -p 8001 &>> test_output.txt


    # ICMP chain test
    echo "\n================================================================================" &>> test_output.txt
    echo "Icmp Test: type 8, PASS if 3 packets received." &>> test_output.txt
    hping3 -V -c 3 -1 $remote_ssh_server_ip -C 8 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Icmp Test: type 13, PASS if packet drop/lost." &>> test_output.txt
    hping3 -V -c 3 -1 $remote_ssh_server_ip -C 13 &>> test_output.txt


    # mangle test, show the mangle table count increased
    echo "\n================================================================================" &>> test_output.txt
    echo "Mangle Test: ftp, PASS if iptables counter is 3." &>> test_output.txt
    hping3 -V -c 3 $remote_ssh_server_ip -S -p 21 &>> test_output.txt
    echo "\n================================================================================" &>> test_output.txt
    echo "Mangle Test: ssh, PASS if iptables counter is 3." &>> test_output.txt
    hping3 -V -c 3 $remote_ssh_server_ip -S -p 22 &>> test_output.txt

    printf "END TEST"
    echo "END TEST" &>> test_output.txt
}



while true
do
	# clear
	 cat << 'MENU'
 	1................................... Run External Test Script
 	2................................... Run Internal Test Script
 	0................................... Quit
MENU
	echo -n '           Input number for choice, then Return >'
	read number rest
	case ${number} in
		[1])	external_test_function ;;
		[2])	internal_test_function ;;
		[0])	exit	;;
		*)	echo; echo Unrecognized choice: ${number} ;;
	esac
	echo; echo -n ' Press Enter to continue.....'
	read rest
done

