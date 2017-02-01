FROM clearwater/base
MAINTAINER DCG DSG DNSG Container SW Directs <dcg.dsg.dnsg.container.sw.directs@intel.com>

ARG PROXY
ARG NO_PROXY
ENV http_proxy $PROXY
ENV https_proxy $PROXY

COPY etcd /bin/etcd
COPY etcdctl /bin/etcdctl
RUN no_proxy=$NO_PROXY apt-get update && no_proxy=$NO_PROXY apt-get -y install tcpdump ngrep curl dnsutils nmap
RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractive no_proxy=$NO_PROXY apt-get install -y supervisor curl
COPY etcd.conf /etc/supervisor/conf.d/etcd.conf

ENV http_proxy ''
ENV https_proxy ''
