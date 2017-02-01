#!/bin/sh

IP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
MASKCIDR=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f2)

CLASSC=$(expr "$MASKCIDR" \>\= 24)
CLASSB=$(expr "$MASKCIDR" \>\= 16)
CLASSA=$(expr "$MASKCIDR" \>\= 8)

octet1=$(echo "$IP" | awk -F. '{print $1}')
octet2=$(echo "$IP" | awk -F. '{print $2}')
octet3=$(echo "$IP" | awk -F. '{print $3}')
octet4=$(echo "$IP" | awk -F. '{print $4}')

if [ "$CLASSC" = "1" ]; then
  OCTETS="$octet3.$octet2.$octet1"
  OCTETS_ARPA="$octet3.$octet2.$octet1"
elif [ "$CLASSB" = "1" ]; then
  OCTETS="0.$octet2.$octet1"
  OCTETS_ARPA="$octet2.$octet1"
elif [ "$CLASSA" = "1" ]; then
  OCTETS="0.0.$octet1"
  OCTETS_ARPA="$octet1"
else
  OCTETS="0.0.0"
  OCTETS_ARPA=""
fi

sed "s/REV_OCTETS_ARPA/$OCTETS_ARPA/g" -i /etc/bind/named.conf
sed "s/REV_OCTETS/$OCTETS/g" -i /etc/bind/named.conf


cat > "/etc/bind/db.$DNSZONE.conf" <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DNSZONE. admin.$DNSZONE. (
                  5     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
$DNSZONE.     IN      NS      ns1.$DNSZONE.

; name servers - A records
ns1          IN      A      $IP
EOF


cat > "/etc/bind/db.$OCTETS.conf" <<EOF
\$TTL    86400
@       IN      SOA     $DNSZONE. admin.$DNSZONE. (
                              5         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                          86400 )       ; Negative Cache TTL
;
       IN      NS      ns1.$DNSZONE.
\$ORIGIN $octet3.$octet2.$octet1.in-addr.arpa.
$octet4 IN      PTR     ns1.$DNSZONE. ;
EOF

