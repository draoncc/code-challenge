#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

VULTR_ACCESS_TOKEN="${VULTR_ACCESS_TOKEN:-}"
K8S_MACHINE="dind-kubernetes"
REG_MACHINE="docker-registry"
DEV_MACHINE="docker-development"
REG_PORT="443"
TMP="/tmp/docker-env-deploy"
mkdir -p ${TMP}

function dpl::cleanup {
  rm -rf ${TMP}
}

trap dpl::cleanup EXIT

function dpl::switch-machine {
  eval $(docker-machine env $1)
}

function dpl::cur-ip {
  echo $(docker-machine ip ${DOCKER_MACHINE_NAME})
}

function dpl::create-certs {
  echo "Creating certificates" >&2
  mkdir -p ${TMP}/certs
  echo "subjectAltName = IP:$(docker-machine ip ${REG_MACHINE})" > ${TMP}/extfile.cnf
  openssl req \
    -newkey rsa:4096 -nodes -sha256 \
    -subj "/C=AU/ST=State/L=City/O=Company/CN=$(docker-machine ip ${REG_MACHINE})" \
    -keyout ${TMP}/certs/domain.key \
    -x509 -days 365 \
    -extensions SAN \
    -config <(cat /etc/ssl/openssl.cnf \
      <(printf "\n[SAN]\nsubjectAltName=IP:$(docker-machine ip ${REG_MACHINE})")) \
    -out ${TMP}/certs/domain.crt
  docker-machine scp -r ${TMP}/certs ${REG_MACHINE}:/
}

function dpl::install-certs {
  # While it is unnecessary to deploy the certs to the k8s
  # machine because the nodes appear to not use
  # /usr/local/share/ca-certificate, I chose to continue
  # doing it for future testing.
  #
  # The nodes also continue to bind
  # /usr/local/share/ca-certificates as a volume
  # in my modified dind-cluster script.
  declare -a machines=(${K8S_MACHINE} ${DEV_MACHINE})
  for machine in "${machines[@]}" ; do
    echo "Installing certificates on ${machine}" >&2
    dpl::switch-machine ${machine}
    docker-machine ssh ${machine} -- mkdir -p \
      /etc/docker/certs.d/$(docker-machine ip ${REG_MACHINE}):${REG_PORT}
    docker-machine scp ${TMP}/certs/domain.crt \
      ${machine}:/etc/docker/certs.d/$(docker-machine ip ${REG_MACHINE}):${REG_PORT}/ca.crt
    docker-machine ssh ${machine} -- cp \
      /etc/docker/certs.d/$(docker-machine ip ${REG_MACHINE}):${REG_PORT}/ca.crt \
      /usr/local/share/ca-certificates/$(docker-machine ip ${REG_MACHINE}).crt
    docker-machine ssh ${machine} -- systemctl restart docker
  done

  # For the k8s cluster we define the registry as insecure
  # To do this, we must create a docker daemon.json that
  # will be uploaded to each node.
  #
  # This file is uploaded to each node with docker cp in my
  # modified dind-cluster script.
  echo "{ \"insecure-registries\": [\"$(docker-machine ip ${REG_MACHINE}):${REG_PORT}\"] }" > k8s-daemon.json
}

function dpl::create-machine {
  if [ type docker-machine-driver-vultr >/dev/null 2>&1 ] ; then
    echo "docker-machine-driver-vultr not found, installing" >&2
    curl \
      -L https://github.com/janeczku/docker-machine-vultr/releases/download/v1.3.0/docker-machine-driver-vultr-`uname -s`-`uname -m` \
      -o ${TMP}/docker-machine-driver-vultr
    chmod +x ${TMP}/docker-machine-driver-vultr
    cp ${TMP}/docker-machine-driver-vultr /usr/local/bin/docker-machine-driver-vultr
  fi

  docker-machine create \
    --driver vultr \
    --vultr-api-key=${VULTR_ACCESS_TOKEN} \
    --vultr-os-id=241 \
    --vultr-region-id=9 \
    --vultr-plan-id=${2:-201} \
    $1
}

function dpl::run-reg {
  dpl::switch-machine "${REG_MACHINE}"
  if [ "$(docker ps -a | grep registry)" ] ; then
    docker stop registry
    docker rm registry
  fi
  REG_SHA="$(docker run \
    -d \
    --name registry \
    -v /certs:/certs \
    -v /mnt/registry:/var/lib/registry \
    -e REGISTRY_HTTP_ADDR=$(dpl::cur-ip):443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    -p $(dpl::cur-ip):${REG_PORT}:443 \
    --network=host \
    registry:2)"
  echo "reg sha: ${REG_SHA}" >&2
}

function dpl::clean {
  docker-machine rm -y ${K8S_MACHINE} &
  docker-machine rm -y ${REG_MACHINE} &
  docker-machine rm -y ${DEV_MACHINE} &
  rm -rf ${TMP}
}

case "${1:-}" in
  setup)
    dpl::create-machine ${K8S_MACHINE} 203 &
    dpl::create-machine ${REG_MACHINE} &
    dpl::create-machine ${DEV_MACHINE} &
    ;;
  certs)
    dpl::create-certs
    dpl::install-certs
    ;;
  run-reg)
    dpl::run-reg
    ;;
  clean)
    dpl::clean
    ;;
  reset-k8s)
    docker-machine rm -y ${K8S_MACHINE}
    dpl::create-machine ${K8S_MACHINE} 203
    dpl::create-certs
    dpl::install-certs
    dpl::run-reg
    ;;
  *)
    echo "usage:" >&2
    echo "  $0 clean" >&2
    exit 1
    ;;
esac
