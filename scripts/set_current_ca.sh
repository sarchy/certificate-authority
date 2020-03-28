#! /usr/bin/env sh

home=./data
ca_name=""

for arg in "$@"; do
	key="${arg%%=*}"
	value="${arg#*=}"

	shift

	case "${key}" in
		--ca-home) home="${value}";;
		--ca-cert) ca_name="${value}";;
		*)
			echo "Unknown Argument ${key}" >&2;
			exit 1;
	esac
done

if [ -z "${ca_name}" ]; then
	echo "No ca name provided" >&2;
	exit 1;
fi

if [ "${ca_name}" = "current" ]; then
	echo "${ca_name} is not a valid ca name" >&2;
	exit 1;
fi

ca_file_name=$(echo ${ca_name} | sed -E -e 's/( |\.)/_/g')
dir="${home}/private"

if ! [ -f "${dir}/${ca_file_name}.ca.cert" ]; then
	echo "${ca_name} does not have a corresponding certification (${dir}/${ca_file_name}.ca.cert)" >&2;
	exit 1;
fi

if ! [ -f "${dir}/${ca_file_name}.ca.key" ]; then
	echo "${ca_name} does not have a corresponding private key (${ca_file_name}.ca.key)" >&2;
	exit 1;
fi

ln -f -s ./${ca_file_name}.ca.cert ${dir}/current.ca.cert
ln -f -s ./${ca_file_name}.ca.key ${dir}/current.ca.key
