FROM ubuntu:14.04
MAINTAINER DCG DSG DNSG Container SW Directs <dcg.dsg.dnsg.container.sw.directs@intel.com>

ARG PROXY
ARG REPO
ARG NO_PROXY
ENV http_proxy $PROXY
ENV https_proxy $PROXY

RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractiveno_proxy=$NO_PROXY apt-get install -y openssh-server supervisor curl
RUN mkdir -p /var/run/sshd /var/log/supervisor
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

EXPOSE 22
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

COPY sysctl /sbin/sysctl
RUN sed -e 's/\#\(precedence ::ffff:0:0\/96  100\)/\1/g' -i /etc/gai.conf
RUN if [ -z $REPO ]; then echo "deb http://repo.cw-ngv.com/stable binary/" > /etc/apt/sources.list.d/clearwater.list; else echo "deb $REPO ./" > /etc/apt/sources.list.d/clearwater.list; fi

RUN if [ ! -z $PROXY ] && [ -z $REPO ]; then echo "proxy = $PROXY" > ~/.curlrc; fi
RUN if [ -z $REPO ]; then curl -L http://repo.cw-ngv.com/repo_key | apt-key add - ; fi
RUN if [ -e ~/.curlrc ]; then rm -rf ~/.curlrc; fi

RUN no_proxy=$NO_PROXY apt-get update && DEBIAN_FRONTEND=noninteractive no_proxy=$NO_PROXY apt-get install -y --force-yes clearwater-infrastructure clearwater-auto-config-docker clearwater-management clearwater-cluster-manager

ENV http_proxy ''
ENV https_proxy ''

RUN /etc/init.d/clearwater-auto-config-docker restart
RUN /etc/init.d/clearwater-infrastructure restart
COPY clearwater-infrastructure.supervisord.conf /etc/supervisor/conf.d/clearwater-infrastructure.conf
COPY clearwater-group.supervisord.conf /etc/supervisor/conf.d/clearwater-group.conf
