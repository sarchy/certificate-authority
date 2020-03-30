#! /usr/bin/env bash

home=./data
ca_name="current"
days=$(( 365 * 5 ))

common_name=""

for arg in "$@"; do
	key="${arg%%=*}"
	value="${arg#*=}"

	shift

	case "${key}" in
		--ca-home) home="${value}";;
		--ca-cert) ca_name="${value}";;
		--days) days="${value}";;

		-cn) common_name="${value}";;

		*)
			echo "Unknown Argument ${key}" >&2;
			exit 1;
	esac
done

common_name=${1:-"${common_name}"}

if [ -z "${common_name}" ]; then
	echo "No common name provided" >&2;
	exit 1;
fi

file_name=$(echo ${common_name} | sed -E -e 's/( |\.)/_/g')
ca_file_name=$(echo ${ca_name} | sed -E -e 's/( |\.)/_/g')
dir="${home}/private"

subject=$(
	openssl x509 -in "${home}/private/${ca_file_name}.ca.cert" -subject -noout \
	| sed -e 's/^subject= //' -e 's/\/CN=[^\/,]*/\/CN='"${common_name}"'/'
)

printf "Main Ca Password []:"
read -s password
echo ""

[ -d "${dir}" ] || mkdir -p "${dir}"

[ -f "${dir}/${file_name}.ca.key" ] || openssl genrsa \
	-aes256 -out "${dir}/${file_name}.ca.key" \
	-passout "pass:${password}" \
	2048

[ -f ${dir}/${file_name}.ca.csr ] || openssl req -new -config "./${home}/openssl.cnf" \
	-subj "${subject}" \
	-key "${dir}/${file_name}.ca.key" -out "${dir}/${file_name}.ca.csr" \
	-passout "pass:${password}" -passin "pass:${password}"

[ -f "${dir}/${file_name}.ca.cert" ] || openssl ca -config "./${home}/openssl.cnf" \
	-cert "${home}/private/${ca_file_name}.ca.cert" \
	-keyfile "${home}/private/${ca_file_name}.ca.key" \
	-passin "pass:${password}" \
	-extensions v3_ca_has_san -days "${days}" \
	-out "${dir}/${file_name}.ca.cert" \
	-infiles "${dir}/${file_name}.ca.csr"
