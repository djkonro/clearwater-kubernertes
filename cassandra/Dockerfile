FROM clearwater/base
MAINTAINER DCG DSG DNSG Container SW Directs <dcg.dsg.dnsg.container.sw.directs@intel.com>

ARG PROXY
ARG NO_PROXY
ENV http_proxy $PROXY
ENV https_proxy $PROXY

RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractive no_proxy=$NO_PROXY apt-get install -y --force-yes homestead-cassandra homestead-prov-cassandra homer-cassandra
RUN sed -e 's/-c cassandra/-c root/g' -i /etc/init.d/cassandra

COPY users.create_homestead_cache.casscli /tmp/users.create_homestead_cache.casscli
COPY users.create_homestead_provisioning.casscli /tmp/users.create_homestead_provisioning.casscli
COPY users.create_xdm.cqlsh /tmp/users.create_xdm.cqlsh 

COPY start_cassandra.sh /usr/bin/start_cassandra.sh
COPY cassandra.supervisord.conf /etc/supervisor/conf.d/cassandra.conf
COPY clearwater-group.supervisord.conf /etc/supervisor/conf.d/clearwater-group.conf

ENV http_proxy ''
ENV https_proxy ''

EXPOSE 9160 7001 7001 9042
