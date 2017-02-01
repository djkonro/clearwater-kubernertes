#!/bin/bash -x
#
# Bash Style Guide: https://lug.fh-swf.de/vim/vim-bash/StyleGuideShell.en.pdf
#
#===============================================================================
#
# FILE: start.sh
#
# USAGE: start.sh
#
# DESCRIPTION: Before running supervisorD in clearwater we would like to setup
# some addtionaled DNS configurations
#
# OPTIONS: ---
# REQUIREMENTS: ---
# BUGS: ---
# NOTES: ---
# AUTHOR:  david.m.oneill@intel.com, derek.o.conoor@intel.com
# COMPANY: Intel Corp
# VERSION: 1.0
# CREATED: 30.11.2016
# REVISION: 20.12.2016
#===============================================================================

HOSTNAME=BUILDIMAGE
IP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

#=== FUNCTION ==================================================================
# NAME: pre_run_dns_checks
# DESCRIPTION: Makes sures number of DNS variables and DNS service is ready to
# serves our contianers
#===============================================================================

function pre_run_dns_checks()
{
  if [ -z ${CLEARWATER_DNS_SERVICE_SERVICE_HOST+x} ]; then
    echo "CLEARWATER_DNS_SERVICE_SERVICE_HOST is not defined, did you launch a DNS service?"
    exit 1
  fi

  if [ -z ${DNSZONE+x} ]; then
    echo "DNSZONE is not configured!"
    exit 2
  fi

  if [ -z ${RNDCKEY+x} ]; then
    echo "RNDCKEY is not configured!"
    exit 3
  fi

  if [[ $HOSTNAME != "bind" ]]; then
    # wait for DNS, timeout retunr 124 for timed out
    timeout 2 nslookup ns1.$DNSZONE $CLEARWATER_DNS_SERVICE_SERVICE_HOST
    while [ $? != 0 ]; do
      echo "Waiting for dns ....."
      timeout 2 nslookup ns1.$DNSZONE $CLEARWATER_DNS_SERVICE_SERVICE_HOST
    done
  fi

  if [[ $HOSTNAME != "etcd" ]] && [[ $HOSTNAME != "bind" ]]; then
    # wait for etcd, timeout retunr 124 for timed out
    timeout 2 nslookup etcd.$DNSZONE $CLEARWATER_DNS_SERVICE_SERVICE_HOST
    while [ $? != 0 ]; do
      echo "Waiting for etcd ....."
      timeout 2 nslookup etcd.$DNSZONE $CLEARWATER_DNS_SERVICE_SERVICE_HOST
    done
  fi
}

#=== FUNCTION ==================================================================
# NAME: setup_dns_config
# DESCRIPTION: Setup etc resolv and RNDC key
#===============================================================================

function setup_dns_config()
{
  echo "search $DNSZONE" > /etc/resolv.conf
  echo "nameserver $CLEARWATER_DNS_SERVICE_SERVICE_HOST" >> /etc/resolv.conf
  sed "s/RNDCKEY/$RNDCKEY/g" -i /root/rndc-key
}

#=== FUNCTION ==================================================================
# NAME: updatedns
# DESCRIPTION: Generic nsupdate function that accepts string 'update' command
# PARAMETER 1: String - The full 'update' string eg. 'update add X d Y'
#===============================================================================

function updatedns()
{
  # $1 dns query to send
  (
    echo "server $CLEARWATER_DNS_SERVICE_SERVICE_HOST"
    echo "debug yes"
    echo "zone $DNSZONE"
    echo "$1"
    echo "show"
    echo "send"
  ) | /usr/bin/nsupdate -d -k "/root/rndc-key"
}

#=== FUNCTION ==================================================================
# NAME: push_a_record
# DESCRIPTION: Pushes A record
# PARAMETER 1: hostname (non qualified)
# PARAMETER 2: ip address
#===============================================================================

function push_a_record()
{
  updatedns "update add $1.$DNSZONE 1440 A $2"
}

#=== FUNCTION ==================================================================
# NAME: push_srv_record
# DESCRIPTION: Pushes SRV record
# PARAMETER 1: record name (unqualified)
# PARAMETER 2: ttl of the record
# PARAMETER 3: prioerity of the record
# PARAMETER 4: weight of record
# PARAMETER 5: port number
# PARAMETER 6: hostname taget (unqualified)
#===============================================================================

function push_srv_record()
{
  updatedns "update add $1.$DNSZONE $2 SRV $3 $4 $5 $6"
}

#=== FUNCTION ==================================================================
# NAME: push_naptr_record
# DESCRIPTION: Pushes NAPTR record
# PARAMETER 1: record name (unqualified)
# PARAMETER 2: ttl of the record
# PARAMETER 3: order of the record
# PARAMETER 4: preference of record
# PARAMETER 5: flags of record
# PARAMETER 6: params of record
# PARAMETER 7: regex of record
# PARAMETER 8: replace of record
#===============================================================================

function push_naptr_record()
{
  updatedns "update add $1.$DNSZONE $2 NAPTR $3 $4 \"$5\" \"$6\" \"$7\" $8"
}

#=== FUNCTION ==================================================================
# NAME: delete_record
# DESCRIPTION: Pushes NAPTR record
# PARAMETER 1: record name (unqualified)
# PARAMETER 2: type of the record
#===============================================================================

function delete_record()
{
  updatedns "update delete $1.$DNSZONE $2"
}

#=== FUNCTION ==================================================================
# NAME: launch
# DESCRIPTION: Starts supervisord and any minute last confiurations
#===============================================================================

function launch()
{
  # clearwater log level
  mkdir -vp /etc/clearwater/
  echo "log_level=5" > /etc/clearwater/user_settings
  /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
}

#=== FUNCTION ==================================================================
# NAME: configure_host
# DESCRIPTION: determines the host from case statement and applies the host
# speicific configurations
#===============================================================================

function configure_host()
{
  case "$HOSTNAME" in
    bind)
      chmod +x /etc/bind/generate-zone-file.sh
      /etc/bind/generate-zone-file.sh
      sed "s/RNDCKEY/$RNDCKEY/g" -i /etc/bind/rndc-key
      sed "s/DNSZONE/$DNSZONE/g" -i /etc/bind/named.conf
      sed "s/DNS_FORWARDER_1/$DNS_FORWARDER_1/g" -i /etc/bind/named.conf
      sed "s/DNS_FORWARDER_2/$DNS_FORWARDER_2/g" -i /etc/bind/named.conf
      grep "file \"" logging.conf | awk -F\" '{print $2}' | xargs touch
      grep "file \"" logging.conf | awk -F\" '{print $2}' | xargs chmod 775
      grep "file \"" logging.conf | awk -F\" '{print $2}' | xargs chown root:bind
      chown root:bind /etc/bind/*
      mkdir /var/bind
      chown root:bind /var/bind
      touch /var/log/namedStdErrOut
      ;;
    bono)
      delete_record "$HOSTNAME" "A"
      delete_record "$HOSTNAME" "NAPTR"
      delete_record "$HOSTNAME" "NAPTR"
      delete_record "$HOSTNAME" "SRV"
      delete_record "$HOSTNAME" "SRV"
      push_a_record "$HOSTNAME" "$CLEARWATER_BONO_SERVICE_SERVICE_HOST"
      push_srv_record "_sip._tcp.$HOSTNAME" "3000" "0" "0" "$CLEARWATER_BONO_SERVICE_SERVICE_PORT" "$HOSTNAME"
      push_srv_record "_sip._udp.$HOSTNAME" "3000" "0" "0" "$CLEARWATER_BONO_SERVICE_SERVICE_PORT" "$HOSTNAME"
      push_naptr_record "$HOSTNAME" "3000" "1" "1" "S" "SIP+D2T" "" "_sip._tcp.$HOSTNAME"
      push_naptr_record "$HOSTNAME" "3000" "1" "1" "S" "SIP+D2U" "" "_sip._udp.$HOSTNAME"
      ;;
    etcd)
      delete_record "$HOSTNAME" "A"
      # TODO: Conflict with kubernetes etcd 4001 if using etcd container with
      # matcing service, since we already have ETCD as part of kubernetes, re-use
      # push_a_record "$HOSTNAME" "$CLEARWATER_ETCD_SERVICE_SERVICE_HOST"
      push_a_record "$HOSTNAME" "$IP"
      ;;
    cassandra)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_CASSANDRA_SERVICE_SERVICE_HOST"
      ;;
    chronos)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_CHRONOS_SERVICE_SERVICE_HOST"
      ;;
    ellis)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_ELLIS_SERVICE_SERVICE_HOST"
      ;;
    homer)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_HOMER_SERVICE_SERVICE_HOST"
      ;;
    homestead)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_HOMESTEAD_SERVICE_SERVICE_HOST"
      delete_record "hs" "A"
      push_a_record "hs" "$CLEARWATER_HOMESTEAD_SERVICE_SERVICE_HOST"
      ;;
    memcached)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_MEMCACHED_SERVICE_SERVICE_HOST"
      ;;
    ralf)
      delete_record "$HOSTNAME" "A"
      push_a_record "$HOSTNAME" "$CLEARWATER_RALF_SERVICE_SERVICE_HOST"
      ;;
    sprout)
      delete_record "$HOSTNAME" "A"
      delete_record "$HOSTNAME" "NAPTR"
      delete_record "$HOSTNAME" "NAPTR"
      delete_record "$HOSTNAME" "SRV"

      delete_record "scscf.$HOSTNAME" "A"
      delete_record "scscf.$HOSTNAME" "NAPTR"
      delete_record "_sip._tcp.scscf.$HOSTNAME" "SRV"

      delete_record "icscf.$HOSTNAME" "A"
      delete_record "icscf.$HOSTNAME" "NAPTR"
      delete_record "_sip._tcp.icscf.$HOSTNAME" "SRV"

      push_a_record "$HOSTNAME" "$CLEARWATER_SPROUT_SERVICE_SERVICE_HOST"
      push_naptr_record "$HOSTNAME" "3000" "1" "1" "S" "SIP+D2T" "" "_sip._tcp.$HOSTNAME"
      push_srv_record "_sip._tcp.$HOSTNAME" "3000" "0" "0" "$CLEARWATER_SPROUT_SERVICE_SERVICE_PORT" "$HOSTNAME"

      push_a_record "scscf.$HOSTNAME" "$CLEARWATER_SPROUT_SERVICE_SERVICE_HOST"
      push_naptr_record "scscf.$HOSTNAME" "3000" "1" "1" "S" "SIP+D2T" "" "_sip._tcp.scscf.$HOSTNAME"
      push_srv_record "_sip._tcp.scscf.$HOSTNAME" "3000" "0" "0" "$CLEARWATER_SPROUT_SERVICE_SERVICE_PORT" "scscf.$HOSTNAME"

      push_a_record "icscf.$HOSTNAME" "$CLEARWATER_SPROUT_SERVICE_SERVICE_HOST"
      push_naptr_record "icscf.$HOSTNAME" "3000" "1" "1" "S" "SIP+D2T" "" "_sip._tcp.icscf.$HOSTNAME"
      push_srv_record "_sip._tcp.icscf.$HOSTNAME" "3000" "0" "0" "$CLEARWATER_SPROUT_SERVICE_SERVICE_PORT" "icscf.$HOSTNAME"
      ;;
  esac
}

pre_run_dns_checks
setup_dns_config
configure_host
launch
