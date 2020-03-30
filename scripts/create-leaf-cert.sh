#! /usr/bin/env bash

home=./data
ca_name="current"
group="constructing"
days="$(( 365 * 1 ))"

common_name=""
altnames=()

for arg in "$@"; do
	key="${arg%%=*}"
	value="${arg#*=}"

	shift

	case "${key}" in
		--ca-home) home="${value}";;
		--ca-cert) ca_name="${value}";;
		--group) group="${value}";;
		--days) days="${value}";;

		-cn) common_name="${value}";;
		-alt) altnames+=("${value}");;

		--)
			shift;
			break;;

		-*)
			echo "Unknown Argument ${key}" >&2;
			exit 1;;

		*)
			comomn_name="${arg}"
			break;;
	esac
done

altnames=("${common_name}" "${altnames[@]}")

if [ -z "${common_name}" ]; then
	echo "No common name provided" >&2;
	exit 1;
fi

if [ "${group}" = "private" ]; then
	echo "private is a reserved group name" >&2;
	exit 1;
fi

file_name=$(echo ${common_name} | sed -E -e 's/( |\.)/_/g')
ca_file_name=$(echo ${ca_name} | sed -E -e 's/( |\.)/_/g')
dir="${home}/${group}"

config_file_name="${home}/openssl.cnf"
if [[ "${#altnames[@]}" -gt 1 ]]; then
	config_file_name="${dir}/${file_name}.cnf";
fi

subject=$(
	openssl x509 -in ${home}/private/${ca_file_name}.ca.cert -subject -noout \
	| sed -e 's/^subject= //' -e 's/\/CN=[^\/,]*/\/CN='"${common_name}"'/'
)

printf "Main Ca Password []:"
read -s password
echo ""

[ -d ${dir} ] || mkdir -p ${dir}

[[ "${#altnames[@]}" -gt 1 ]] && cat > "${config_file_name}" <<-EOF
	######################################################################################
	# This is where we define how to generate CSRs
	#
	[ req ]
	string_mask             = utf8only
	req_extensions		    = v3_req                 # The extensions to add to req's
	distinguished_name      = req_distinguished_name

	[req_distinguished_name]

	######################################################################################
	# Extension for requests
	#
	[ v3_req ]

	# Lets at least make our requests PKIX complaint
	subjectAltName = @altnames

	######################################################################################
	# Additional alternative names
	#
	[ altnames ]
	$(
		for i in ${!altnames[@]}; do
			echo "DNS.${i} = ${altnames[i]}"
		done
	)
EOF

[ -f "${dir}/${file_name}.key" ] || openssl genrsa \
	-aes256 -out "${dir}/${file_name}.key" \
	-passout "pass:${password}" \
	2048

[ -f "${dir}/${file_name}.csr" ] || openssl req -new -config "${config_file_name}" \
	-key "${dir}/${file_name}.key" -out "${dir}/${file_name}.csr" \
	-passin "pass:${password}" -passout "pass:${password}" \
	-subj "${subject}"

[ -f "${dir}/${file_name}.cert" ] || openssl ca -config "${home}/openssl.cnf" \
	-cert "${home}/private/${ca_file_name}.ca.cert" \
	-keyfile "${home}/private/${ca_file_name}.ca.key" \
	-passin "pass:${password}" \
	-extensions usr_cert_has_san -days "${days}" \
	-out "${dir}/${file_name}.cert" \
	-infiles "${dir}/${file_name}.csr"

if ! [ -f "${dir}/${file_name}.chain" ]; then
	> ${dir}/${file_name}.chain
	current="${dir}/${file_name}.cert";
	while true; do
		issuer=$(grep -i 'Issuer: ' "${current}" | sed -e 's/^.*Issuer: /Subject: /')
		subject=$(grep -i 'Subject: ' "${current}" | sed -e 's/^.*Subject: /Subject: /')

		if [ "${issuer}" = "${subject}" ]; then break; fi

		current=$(grep -i "${issuer}" "${home}/certsdb/"* | sed -e 's/^\([^:]*\):.*$/\1/')
		cat "${current}" >> "${dir}/${file_name}.chain"
	done
fi

[ -f "${dir}/${file_name}.p12" ] || openssl pkcs12 -export -name "${file_name}" \
	-inkey "${dir}/${file_name}.key" -in "${dir}/${file_name}.cert" \
	-certfile "${dir}/${file_name}.chain" \
	-passin "pass:${password}" -passout "pass:${password}" \
	-out "${dir}/${file_name}.p12"
