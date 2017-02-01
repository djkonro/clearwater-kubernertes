FROM clearwater/base
MAINTAINER DCG DSG DNSG Container SW Directs <dcg.dsg.dnsg.container.sw.directs@intel.com>

ARG PROXY
ARG NO_PROXY
ENV http_proxy $PROXY
ENV https_proxy $PROXY

RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractive no_proxy=$NO_PROXY apt-get install -y bind9 supervisor curl tcpdump ngrep curl dnsutils nmap
COPY named.conf /etc/supervisor/conf.d/named.conf

RUN mkdir -vp /etc/bind/
ADD named-authorative.conf /etc/bind/named.conf
ADD logging.conf /etc/bind/logging.conf
ADD generate-zone-file.sh /etc/bind/generate-zone-file.sh
ADD rndc-key /etc/bind/rndc-key

RUN rm -f /etc/bind/named.conf.authoritative
RUN rm -f /etc/bind/named.conf.recursive
RUN rm -f /etc/bind/bind.keys

RUN chmod 777 /etc/bind/.
RUN chmod 777 /etc/bind/*

ENV http_proxy ''
ENV https_proxy ''

CMD ["/root/start.sh"]

EXPOSE 53
