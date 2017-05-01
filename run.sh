#!/bin/bash -x
#
# Bash Style Guide: https://lug.fh-swf.de/vim/vim-bash/StyleGuideShell.en.pdf
#
#===============================================================================
#
# FILE: run.sh
#
# USAGE: run.sh
#
# DESCRIPTION: Builds and executes IMS Clearwater on Kubernetes
#
# OPTIONS: ---
# REQUIREMENTS: ---
# BUGS: ---
# NOTES: ---
# AUTHOR:  david.m.oneill@intel.com, derek.o.conoor@intel.com
# COMPANY: Intel Corp
# VERSION: 1.0
# CREATED: 30.11.2016
# REVISION: 24.01.2017
#===============================================================================

IFS=$' \t\n'
SEP=$(printf '#%.0s' {1..80})
PWD=$(pwd)
STRLEN_REGISTRY=0

folders="base etcd bono cassandra chronos ellis homer homestead memcached ralf sprout bind"

#=== FUNCTION ==================================================================
# NAME: check_conf
# DESCRIPTION: Check that the environment vars have been configured
#===============================================================================

function check_conf()
{
  source run.conf

  if [ $? != 0 ]; then
    echo "Failed to source run.conf, does it exist?"
  fi

  REQ_VARS="DNSKEY USERZONE NODEHOST DNSFORWARDER1 DNSFORWARDER2 REGISTRY_HOST IMAGE_PREFIX"

  for REQ in $REQ_VARS; do
    if [[ -z $REQ ]]; then
      echo "$REQ is not set, is the file run.conf configured?"
      exit 2
    fi
  done

  STRLEN_REGISTRY=${#REGISTRY_HOST}
}

#=== FUNCTION ==================================================================
# NAME: cleanup_images
# DESCRIPTION: Cleans up images locally and removes them off remote docker
# registry
#===============================================================================

function cleanup_images()
{
  echo $SEP
  read -p "Remove docker images? [y/N]" -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]; then

    IFS=$'\n'

    for X in `docker images --digests`; do
      line=$X;
      name=$(echo $X | awk '{print $1}')
      digest=$(echo $X | awk '{print $3}')

      if [[ $name == *"$IMAGE_PREFIX"* ]]; then
        curl -k -X DELETE https://$REGISTRY_HOST/v2/${name:$STRLEN_REGISTRY}/manifests/$digest
      fi
    done

    IFS=$' \t\n'

    docker rmi -f `docker images -aq`
  fi
}

#=== FUNCTION ==================================================================
# NAME: build_base_images
# DESCRIPTION: Builds clearwater base images
#===============================================================================

function build_base_images()
{
  echo $SEP
  read -p "Rebuild images? [y/N]" -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for X in $folders; do
      \cp -rf $PWD/utils/rndc-key $X/
      \cp -rf $PWD/utils/start.sh $X/
      sed 's/BUILDIMAGE/$image/' -i $X/start.sh
      docker build --build-arg PROXY=$PROXY --build-arg REPO=$REPOSITORY --build-arg NO_PROXY=$NO_PROXY -t clearwater/$X $X
    done
  fi
}

#=== FUNCTION ==================================================================
# NAME: rebase_images
# DESCRIPTION: Updates the images with modifications rebasing off the base
# images for faster deployment
#===============================================================================

function rebase_images()
{
  echo $SEP
  read -p "Rebase images? [y/N]" -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for image in $folders; do
      echo $SEP
      \cp -rf $PWD/utils/start.sh $image/
      \cp -rf $PWD/utils/rndc-key $image/
      chmod +x $image/start.sh
      sed "s/BUILDIMAGE/$image/" -i $image/start.sh

      cd $image
      echo $image

      if [ -f ./Dockerfile.new ]; then
        rm -rf ./Dockerfile.new
      fi

      echo "FROM clearwater/$image" > Dockerfile.new
      echo "ARG PROXY" >> Dockerfile.new
      echo "ENV http_proxy \$PROXY" >> Dockerfile.new
      echo "ENV https_proxy \$PROXY" >> Dockerfile.new
      echo "RUN no_proxy=$NO_PROXY apt-get update && no_proxy=$NO_PROXY apt-get -y install tcpdump ngrep curl dnsutils nmap ldnsutils" >> Dockerfile.new
      echo "COPY rndc-key /root/rndc-key" >> Dockerfile.new
      echo "COPY start.sh /root/start.sh" >> Dockerfile.new

      if [[ $image == "bind" ]]; then
        echo "COPY named.conf /etc/supervisor/conf.d/named.conf" >> Dockerfile.new
        echo "ADD named-authorative.conf /etc/bind/named.conf" >> Dockerfile.new
        echo "ADD logging.conf /etc/bind/logging.conf" >> Dockerfile.new
        echo "ADD generate-zone-file.sh /etc/bind/generate-zone-file.sh" >> Dockerfile.new
        echo "ADD rndc-key /etc/bind/rndc-key" >> Dockerfile.new
      fi

      if [[ $image == "etcd" ]]; then
        echo "COPY etcd.conf /etc/supervisor/conf.d/etcd.conf" >> Dockerfile.new
      fi

      if [[ $image == "cassandra" ]]; then
        echo "COPY users.create_homestead_cache.casscli /tmp/users.create_homestead_cache.casscli" >> Dockerfile.new
        echo "COPY users.create_homestead_provisioning.casscli /tmp/users.create_homestead_provisioning.casscli" >> Dockerfile.new
        echo "COPY users.create_xdm.cqlsh /tmp/users.create_xdm.cqlsh" >> Dockerfile.new
        echo "COPY start_cassandra.sh /usr/bin/start_cassandra.sh" >> Dockerfile.new
        echo "COPY cassandra.supervisord.conf /etc/supervisor/conf.d/cassandra.conf" >> Dockerfile.new
        echo "COPY clearwater-group.supervisord.conf /etc/supervisor/conf.d/clearwater-group.conf" >> Dockerfile.new
      fi

      echo "ENV http_proxy ''" >> Dockerfile.new
      echo "ENV https_proxy ''" >> Dockerfile.new

      docker build --build-arg PROXY=$PROXY -t $image-test -f Dockerfile.new .
      TAG=$(docker images -a | grep ^$image-test | awk '{print $3}')
      docker tag $TAG $REGISTRY_HOST/$IMAGE_PREFIX/clearwater/$image-test
      docker push $REGISTRY_HOST/$IMAGE_PREFIX/clearwater/$image-test

      cd ..
    done
  fi
}

#=== FUNCTION ==================================================================
# NAME: generate_k8s_json
# DESCRIPTION: Gnerate the kubernet all-in-oone json file subsiturting variables
# ass appropriate
#===============================================================================

function generate_k8s_json()
{
  \cp -rf utils/aio-template.json utils/aio.json
  sed "s/DNSKEY/$DNSKEY/g" -i utils/aio.json
  sed "s/USERZONE/$USERZONE/g" -i utils/aio.json
  sed "s/NODEHOST/$NODEHOST/g" -i utils/aio.json
  sed "s/DNSFORWARDER1/$DNSFORWARDER1/g" -i utils/aio.json
  sed "s/DNSFORWARDER2/$DNSFORWARDER2/g" -i utils/aio.json
  sed "s/REGISTRY_HOST/$REGISTRY_HOST/g" -i utils/aio.json

  #if no prefix set remove /
  if [ -z "$IMAGE_PREFIX" ]; then
    sed -ie "s/IMAGE_PREFIX\///g" utils/aio.json
  fi
  sed -ie "s/IMAGE_PREFIX/$IMAGE_PREFIX/g" utils/aio.json

}

#=== FUNCTION ==================================================================
# NAME: k8s_launch
# DESCRIPTION: Undeploy and redeploys IMS onto kubernetes
#===============================================================================

function k8s_launch()
{
  kubectl delete -f utils/aio.json
  sleep 10
  kubectl create -f utils/aio.json
}

check_conf
cleanup_images
build_base_images
rebase_images
generate_k8s_json
k8s_launch
