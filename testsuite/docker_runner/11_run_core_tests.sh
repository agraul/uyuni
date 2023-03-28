#!/bin/bash
set -xe
docker exec controller-test bash -c "export CUCUMBER_PUBLISH_TOKEN=${CUCUMBER_PUBLISH_TOKEN} && export PROVIDER=docker && export SERVER=uyuni-server-all-in-one-test && export HOSTNAME=controller-test && cd /testsuite && rake cucumber:container_core"

