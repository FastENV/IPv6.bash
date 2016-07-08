#!/bin/bash

# Developed in fastenv.ru

ipMaskToEndLength(){
	# Echo IPv6 length - prefix length
	# Return 1 if netMask not valid

	local netMask

	netMask="${1}"
	if ! [[ ${netMask} =~ ^[0-9]+$ ]] ||\
		((netMask%4!=0)) ||\
		((netMask>128))
	then
		return 1
	fi
	echo $((32-netMask/4))
}

ipGenEnd(){
	# Generate random IPv6 postfix

	local netMask
	local ipEnd count char
	local countStop hexStr

	netMask="${1}"
	if ! countStop=$(ipMaskToEndLength "${netMask}")
	then
		return 1
	fi
	hexStr=$(openssl rand -hex ${countStop})
	while char=${hexStr:${count}:1}
	do
		ipEnd="${char}${ipEnd}"
		if ((++count==countStop))
		then
			break
		fi
		if ((count%4==0))
		then
			ipEnd=":${ipEnd}"
		fi
	done
	echo "${ipEnd}"
}

ipGenSubnet(){
	# Generate subnet for prefix

	local ipPrefix ipPrefixMask
	local subnetMask subnetMaskLen
	local ipPrefixMaskLen maskLen
	local count hexStr char netEnd
	local rest

	ipPrefix="${1}"
	ipPrefixMask="${2}"
	subnetMask="${3}"
	if ((subnetMask<ipPrefixMask))
	then
		return 1
	fi
	ipPrefixMaskLen=$(ipMaskToEndLength ${ipPrefixMask})
	subnetMaskLen=$(ipMaskToEndLength ${subnetMask})
	maskLen=$((ipPrefixMaskLen-subnetMaskLen))
	rest=$((ipPrefixMaskLen%4))
	hexStr=$(openssl rand -hex ${maskLen})
	while ((count<maskLen))
	do
		if (((count+rest)%4==0))
		then
			netEnd+=":"
		fi
		char=${hexStr:${count}:1}
		netEnd+="${char}"
		((count++))
	done
	echo "${ipPrefix}${netEnd}"

}

ipConcatinate(){
	local ipPrefix ipEnd

	ipPrefix="${1}"
	ipEnd="${2}"
	if ((${#ipPrefix}%5==4))
	then
		echo "${ipPrefix}:${ipEnd}"
		return 0
	fi
	echo "${ipPrefix}${ipEnd}"
}

ipValidate(){
	local ipAddr
	local octMas ipType score

	ipAddr="${1}"
	octMas=(${ipAddr//:/ })
	ipType=6
	if ((${#octMas[@]}<2))
	then
		octMas=(${ipAddr//./ })
		ipType=4
	fi
	for oct in ${octMas[@]}
	do
		case "${ipType}" in
			4)
				if [[ "${oct}" =~ [0-9]+ ]] && ((oct<256))
				then
					((score++))
				fi
				;;
			6)
				if ((score>0)) && [[ -z "${oct}" ]]
				then
					((score++))
				fi
				if [[ "${oct}" =~ [a-f0-9]+ ]]
				then
					((score++))
				fi
				;;
		esac
	done
	case "${ipType}" in
		4)
			if ((score==4))
			then
				return 0
			fi
			;;
		6)
			if ((score==8))
			then
				return 0
			fi
			;;
	esac
	return 1
}

ipPrefixToFullName(){
	local ipPrefix ipPrefixMask
	local prefixLen prefixMas tailLen oct
	local fullOct i char charCount octCount

	ipPrefix="${1}"
	ipPrefixMask="${2}"
	if ! [[ "${ipPrefix}" ]]
	then
		return 1
	fi
	if ! prefixLen=$(ipMaskToEndLength "${ipPrefixMask}")
	then
		return 2
	fi
	prefixLen=$((32-prefixLen))
	fullOct=$((prefixLen/4))
	tailLen=$((prefixLen-fullOct*4))
	while char=${ipPrefix:${charCount}:1}
	do
		((charCount++))
		char="${char,,}"
		case "${char}" in
			[a-f0-9])
				oct+="${char}"
				;;
			":")
				while ((${#oct}<4))
				do
					oct="0${oct}"
				done
				prefixMas[$((octCount++))]="${oct}"
				unset oct
				if ((octCount>fullOct))
				then
					break
				fi
				;;
			"")
				if ((${#oct}>0))
				then
					if ((tailLen==0))
					then
						while ((${#oct}<4))
						do
							oct="0${oct}"
						done
					fi
					prefixMas[$((octCount++))]="${oct}"
				fi
				break
				;;
		esac
	done
	if ((fullOct>0))
	then
		echo -n "${prefixMas[0]}"
	else
		echo "${prefixMas[0]:0:${tailLen}}"
		return 0
	fi
	for ((i=1; i<fullOct; i++))
	do
		echo -n ":${prefixMas[${i}]}"
	done
	if ((tailLen>0))
	then
		oct=${prefixMas[${fullOct}]}
		echo -n ":${oct:0:${tailLen}}"
	fi
	echo
}

ipGrepSubnet(){
	# Check that netTarget belongs to netIn

	local netIn netInMask netTarget netTargetMask
	local var netInPrefix netTargetPrefix 

	netIn="${1}"
	netInMask="${2}"
	netTarget="${3}"
	netTargetMask="${4}"
	for var in netInMask netTargetMask
	do
		if ! [[ "${!var}" =~ ^[0-9]+$ ]]
		then
			return 1
		fi
		if ((${!var}>128))
		then
			return 2
		fi
	done
	if ((netInMask<netTargetMask))
	then
		return 0
	fi
	if ((netInMask==netTargetMask)) &&\
		((${#netIn}==${#netTarget}))
	then
		netInPrefix="${netIn}"
		netTargetPrefix="${netTarget}"
	else
		netInPrefix=$(ipPrefixToFullName "${netIn}" "${netInMask}")
		netTargetPrefix=$(ipPrefixToFullName "${netTarget}" "${netInMask}")
	fi
	if [[ "${netInPrefix}" == "${netTargetPrefix}" ]]
	then
		return 0
	fi
	return 3
}

ipPrefixIncrement(){
	local ipPrefix ipPrefixMask
	local var ipPrefixFullName
	local oct dec hex ipPrefixMas

	ipPrefix="${1}"
	ipPrefixMask="${2}"
	for var in ipPrefix ipPrefixMask
	do
		if ! [[ "${!var}" ]]
		then
			return 1
		fi
	done
	ipPrefixFullName=$(ipPrefixToFullName "${ipPrefix}" "${ipPrefixMask}")
	for oct in ${ipPrefixFullName//:/ }
	do
		ipPrefixMas+=($(printf "%d" "0x${oct}"))
	done
	for ((var=$((${#ipPrefixMas[@]}-1)); var>=0; var--))
	do
		dec=$((${ipPrefixMas[${var}]}+1))
		if ((dec<65536))
		then
			ipPrefixMas[${var}]="${dec}"
			break
		fi
		ipPrefixMas[${var}]=0
	done
	for ((var=0; var<$((${#ipPrefixMas[@]}-1)); var++))
	do
		dec=${ipPrefixMas[${var}]}
		hex=$(printf "%x" "${dec}")
		while ((${#hex}<4))
		do
			hex="0${hex}"
		done
		echo -n "${hex}:"
	done
	dec=${ipPrefixMas[${var}]}
	hex=$(printf "%x" "${dec}")
	while ((${#hex}<4))
	do
		hex="0${hex}"
	done
	echo "${hex}"
}
