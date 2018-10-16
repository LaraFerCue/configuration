#!/bin/sh
# shellcheck disable=SC2046,SC2068

if ! docker-machine ls | grep docker1 | grep -q 'Running' ; then
	docker-machine create --driver virtualbox \
		--virtualbox-memory 2048 \
		--virtualbox-cpu-count 2 \
		--virtualbox-disk-size 102400 \
		--virtualbox-hostonly-cidr "10.2.1.1/24" \
		docker1
fi

eval $(docker-machine env docker1)

docker ${@}
