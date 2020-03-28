#! /usr/bin/env sh

home=./data
ca_name="current"

common_name=""

for arg in "$@"; do
	key="${arg%%=*}"
	value="${arg#*=}"

	shift

	case "${key}" in
		--ca-home) home="${value}";;
		--ca-cert) ca_name="${value}";;

		--cn) common_name="${value}";;

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
dir="${home}/constructing"

subject=$(
	openssl x509 -in ${home}/private/${ca_file_name}.ca.cert -subject -noout \
	| sed -e 's/^subject= //' -e 's/\/CN=[^\/,]*/\/CN='"${common_name}"'/'
)

[ -d ${dir} ] || mkdir -p ${dir}

cat > ${dir}/${file_name}.star.cnf <<-EOF
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
	DNS.1 = ${common_name}
	DNS.2 = *.${common_name}
EOF

[ -f "${dir}/${file_name}.star.key" ] || openssl genrsa -aes256 -out "${dir}/${file_name}.star.key" 2048

[ -f "${dir}/${file_name}.star.csr" ] || openssl req -new -config "${dir}/${file_name}.star.cnf" \
	-key "${dir}/${file_name}.star.key" -out "${dir}/${file_name}.star.csr" \
	-subj "${subject}"

[ -f "${dir}/${file_name}.star.cert" ] || openssl ca -config "${home}/openssl.cnf" \
	-cert "${home}/private/${ca_file_name}.ca.cert" \
	-keyfile "${home}/private/${ca_file_name}.ca.key" \
	-extensions usr_cert_has_san -days 365 \
	-out "${dir}/${file_name}.star.cert" \
	-infiles "${dir}/${file_name}.star.csr"

if ! [ -f "${dir}/${file_name}.star.chain" ]; then
	> ${dir}/${file_name}.star.chain
	current="${dir}/${file_name}.star.cert";
	while true; do
		issuer=$(grep -i 'Issuer: ' "${current}" | sed -e 's/^.*Issuer: /Subject: /')
		subject=$(grep -i 'Subject: ' "${current}" | sed -e 's/^.*Subject: /Subject: /')

		if [ "${issuer}" = "${subject}" ]; then break; fi

		current=$(grep -i "${issuer}" "${home}/certsdb/"* | sed -e 's/^\([^:]*\):.*$/\1/')
		cat "${current}" >> "${dir}/${file_name}.star.chain"
	done
fi

[ -f "${dir}/${file_name}.star.p12" ] || openssl pkcs12 -export -name "${file_name}" \
	-inkey "${dir}/${file_name}.star.key" -in "${dir}/${file_name}.star.cert" \
	-certfile "${dir}/${file_name}.star.chain" \
	-out "${dir}/${file_name}.star.p12"
