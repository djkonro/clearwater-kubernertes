FROM clearwater/base
MAINTAINER DCG DSG DNSG Container SW Directs <dcg.dsg.dnsg.container.sw.directs@intel.com>

ARG PROXY
ARG NO_PROXY
ENV http_proxy $PROXY
ENV https_proxy $PROXY

RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractive no_proxy=$NO_PROXY apt-get install -y --force-yes chronos 

COPY snmpd.supervisord.conf /etc/supervisor/conf.d/snmpd.conf
COPY chronos.supervisord.conf /etc/supervisor/conf.d/chronos.conf
COPY clearwater-group.supervisord.conf /etc/supervisor/conf.d/clearwater-group.conf

ENV http_proxy ''
ENV https_proxy ''

EXPOSE 7253
