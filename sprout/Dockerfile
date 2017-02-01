FROM clearwater/base
MAINTAINER DCG DSG DNSG Container SW Directs <dcg.dsg.dnsg.container.sw.directs@intel.com>

ARG PROXY
ARG NO_PROXY
ENV http_proxy $PROXY
ENV https_proxy $PROXY

RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractive no_proxy=$NO_PROXY apt-get install -y --force-yes sprout
RUN sed -e 's/\(echo 0 > \/proc\/sys\/kernel\/yama\/ptrace_scope\)/# \0/g' -i /etc/init.d/sprout

COPY sprout.supervisord.conf /etc/supervisor/conf.d/sprout.conf
COPY clearwater-group.supervisord.conf /etc/supervisor/conf.d/clearwater-group.conf
COPY plugins/* /usr/share/clearwater/clearwater-cluster-manager/plugins/
COPY reload_memcached_users /usr/share/clearwater/bin/reload_memcached_users

ENV http_proxy ''
ENV https_proxy ''

EXPOSE 5052 5054
