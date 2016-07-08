#!/bin/bash

declare -g SCRIPT_PATH="$(readlink -f "${0%/*}")"

source "${SCRIPT_PATH}/../IPv6.sh"

ipGen48Subnet(){
	local prefix count
	local i j var

	prefix="${1}"
	count="${2}"
	for var in prefix count
	do
		if ! [[ "${!var}" ]]
		then
			return 1
		fi
	done
	for i in {0..65535}
	do
		for ((j=0; j<count; j++))
		do
			echo "${prefix}:$(printf "%x" ${i}):$(ipGenEnd 64)"
		done
	done
}

ipGen48Subnet ${1} ${2}
