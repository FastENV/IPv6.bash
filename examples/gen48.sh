#!/bin/bash

declare -g SCRIPT_PATH="$(readlink -f "${0%/*}")"

source "${SCRIPT_PATH}/../IPv6.sh"

ipGen48Subnet(){
	local prefix count
	local i j

	prefix="${1}"
	count="${2}"
	count="${count:=1}"
	if ! [[ "${prefix}" ]]
	then
		return 1
	fi
	if ! [[ "${count}" =~ ^[0-9]+$ ]]
	then
		return 2
	fi
	for i in {0..65535}
	do
		for ((j=0; j<count; j++))
		do
			echo "${prefix}:$(printf "%x" ${i}):$(ipGenEnd 64)"
		done
	done
}

ipGen48Subnet ${1} ${2}
