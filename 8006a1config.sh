#!/bin/sh


internal_config() {

    i_internal_ip="10.0.0.222"
    #i_external_ip="192.168.1.182"
    #i_internal_subnet="192.168.2.0/24"
    #i_external_subnet="192.168.1.0/24"
    #i_internal_interface="enp0s20u2"
    #i_external_interface="wlp1s0"
    i_internal_interface="enp2s0"
    i_external_interface="eno1"
}


external_config() {

    e_internal_ip="10.0.0.111"
    #e_external_ip="192.168.1.195"
    e_external_ip="192.168.0.18"
    e_internal_subnet="10.0.0.0/24"
    #e_external_subnet="192.168.1.0/24"
    e_external_subnet="192.168.0.0/24"
    e_internal_interface="enp2s0"
    e_external_interface="eno1"
}


tcp_allowed_ports_array=("21" "22" "53" "80" "443" "8000")
udp_allowed_ports_array=("7" "21" "22" "53" "80" "443" "8000")
icmp_allowed_types_array=("0" "1" "2" "3" "4" "5" "6" "7" "8" "13")

remote_ssh_server_ip="192.168.0.20"


internal_config
external_config

