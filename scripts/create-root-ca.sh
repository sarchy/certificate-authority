#! /usr/bin/env sh

domain=example.com
home=./data

country="BE"
province="Limburg"
city="Sint-Truiden"
organization="Crossroad Communications NV."
common_name="ROOT CERT G1"

for arg in "$@"; do
	key="${arg%%=*}"
	value="${arg#*=}"

	shift

	case "${key}" in
		--domain) domain="${value}";;
		--ca-home) home="${value}";;

		--c) country="${value}";;
		--st) province="${value}";;
		--l) city="${value}";;
		--o) organization="${value}";;
		--cn) common_name="${value}";;

		*)
			echo "Unknown Argument ${key}" >&2;
			exit 1;
	esac
done

domain=${1:-"${domain}"}
subject="/C=${country}/ST=${province}/L=${city}/O=${organization}/CN=${common_name}"

[ -d "${home}" ] || mkdir "${home}";
[ -d "${home}/certsdb/" ] || mkdir -p "${home}/certsdb"
[ -d "${home}/certreqs/" ] || mkdir -p "${home}/certsdb"
[ -d "${home}/private" ] || mkdir -p "${home}/private"

[ -f "${home}/index.txt" ] || touch "${home}/index.txt"
[ -f "${home}/serial" ] || dd if=/dev/urandom bs=1 count=16 2> /dev/null | od -t x1 -An | sed -e 's/ //g' > data/serial

[ -f data/v3.ext ] || cat > data/v3.ext <<-EOF
	authorityKeyIdentifier = keyid,issuer
	basicConstraints = CA:TRUE
	keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
	subjectKeyIdentifier = hash
EOF

[ -f "${home}/openssl.cnf" ] || cat > "${home}/openssl.cnf" <<-EOF
	HOME                    = ./${home}
	RANDFILE                = \$ENV::HOME/rnd

	######################################################################################
	# CA Definition
	#
	[ ca ]
	default_ca      = CA_default            # The default ca section


	######################################################################################
	# Per the above, this is where we define CA values
	#
	[ CA_default ]

	dir              = ${home}                       # Where everything is kept
	certs            = \$dir/certsdb                 # Where the issued certs are kept
	new_certs_dir    = \$certs                       # default place for new certs.
	database         = \$dir/index.txt               # database index file.
	certificate      = \$dir/private/current.ca.cert # The CA certificate
	private_key      = \$dir/private/current.ca.key  # The private key
	serial           = \$dir/serial                  # The current serial number
	RANDFILE         = \$dir/.rand                   # private random number file

	crldir           = \$dir/crl
	crlnumber        = \$dir/crlnumber               # the current crl number
	crl              = \$crldir/crl.pem              # The current CRL

	# By default we use "user certificate" extensions when signing
	x509_extensions  = usr_cert                      # The extentions to add to the cert

	# Honor extensions requested of us
	copy_extensions	 = copy

	# Comment out the following two lines for the "traditional"
	# (and highly broken) format.
	name_opt         = ca_default                    # Subject Name options
	cert_opt         = ca_default                    # Certificate field options

	# Extensions to add to a CRL. Note: Netscape communicator chokes on V2 CRLs
	# so this is commented out by default to leave a V1 CRL.
	# crlnumber must also be commented out to leave a V1 CRL.
	#crl_extensions        = crl_ext
	default_days     = 365                           # how long to certify for
	default_crl_days = 30                            # how long before next CRL
	default_md       = sha256                        # which md to use.
	preserve         = no                            # keep passed DN ordering

	# A few difference way of specifying how similar the request should look
	# For type CA, the listed attributes must be the same, and the optional
	# and supplied fields are just that :-)
	policy           = policy_match


	######################################################################################
	# The default policy for the CA when signing requests, requires some
	# resemblence to the CA cert
	#
	[ policy_match ]
	countryName             = match                  # Must be the same as the CA
	stateOrProvinceName     = match                  # Must be the same as the CA
	localityName            = match                  # Must be the same as the CA
	organizationName        = match                  # Must be the same as the CA
	organizationalUnitName  = optional               # not required
	commonName              = supplied               # must be there, whatever it is
	emailAddress            = optional               # not required


	######################################################################################
	# An alternative policy not referred to anywhere in this file. Can
	# be used by specifying '-policy policy_anything' to ca(8).
	#
	[ policy_anything ]
	countryName             = optional
	stateOrProvinceName     = optional
	localityName            = optional
	organizationName        = optional
	organizationalUnitName  = optional
	commonName              = supplied
	emailAddress            = optional


	######################################################################################
	# This is where we define how to generate CSRs
	#
	[ req ]
	default_bits            = 2048
	default_keyfile         = privkey.pem
	distinguished_name      = req_distinguished_name # where to get DN for reqs
	attributes              = req_attributes         # req attributes
	x509_extensions		    = v3_ca                  # The extentions to add to self signed certs
	req_extensions		    = v3_req                 # The extensions to add to req's

	# This sets a mask for permitted string types. There are several options.
	# default: PrintableString, T61String, BMPString.
	# pkix   : PrintableString, BMPString.
	# utf8only: only UTF8Strings.
	# nombstr : PrintableString, T61String (no BMPStrings or UTF8Strings).
	# MASK:XXXX a literal mask value.
	# WARNING: current versions of Netscape crash on BMPStrings or UTF8Strings
	# so use this option with caution!
	string_mask = utf8only


	######################################################################################
	# Per "req" section, this is where we define DN info
	#
	[ req_distinguished_name ]
	countryName                     = Country Name (2 letter code)
	countryName_default             = ${country}
	countryName_min                 = 2
	countryName_max                 = 2

	stateOrProvinceName             = State or Province Name (full name)
	stateOrProvinceName_default     = ${province}

	localityName                    = Locality Name (eg, city)
	localityName_default            = ${city}

	0.organizationName              = Organization Name (eg, company)
	0.organizationName_default      = ${organization}

	organizationalUnitName          = Organizational Unit Name (eg, section)

	commonName                      = Common Name (eg, YOUR name)
	commonName_max                  = 64

	emailAddress                    = Email Address
	emailAddress_max                = 64


	######################################################################################
	# We don't want these, but the section must exist
	#
	[ req_attributes ]

	#challengePassword              = A challenge password
	#challengePassword_min          = 4
	#challengePassword_max          = 20
	#unstructuredName               = An optional company name


	######################################################################################
	# Extension for requests
	#
	[ v3_req ]

	# Lets at least make our requests PKIX complaint
	subjectAltName = email:move


	######################################################################################
	# Extensions for when we sign normal certs (specified as default)
	#
	[ usr_cert ]

	basicConstraints = CA:false
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid,issuer
	subjectAltName = email:move

	crlDistributionPoints = URI:https://ca.${domain}/ca.crl

	[ usr_cert_has_san ]

	basicConstraints = CA:false
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid,issuer

	crlDistributionPoints = URI:https://ca.${domain}/ca.crl


	######################################################################################
	# An alternative section of extensions, not referred to anywhere
	# else in the config. We'll use this via '-extensions v3_ca' when
	# using ca(8) to sign another CA.
	#
	[ v3_ca ]

	basicConstraints = CA:true
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid:always,issuer:always
	subjectAltName = email:move

	crlDistributionPoints = URI:https://ca.${domain}/ca.crl

	[ v3_ca_has_san ]

	basicConstraints = CA:true
	subjectKeyIdentifier = hash
	authorityKeyIdentifier = keyid:always,issuer:always

	crlDistributionPoints = URI:https://ca.${domain}/ca.crl
EOF

dir="${home}/private"

[ -f "${dir}/root.ca.key" ] || openssl genrsa -aes256 -out ${dir}/root.ca.key 4096

[ -f "${dir}/root.ca.csr" ] || openssl req -new -config ./${home}/openssl.cnf \
	-subj "${subject}" -days 3650 -extensions v3_ca_has_san \
	-key ${dir}/root.ca.key -out ${dir}/root.ca.csr

[ -f "${dir}/root.ca.cert" ] || openssl ca -config ./${home}/openssl.cnf \
	-create_serial -selfsign -keyfile ${dir}/root.ca.key \
	-subj "${subject}" -days 3650 -extensions v3_ca_has_san \
	-out ${dir}/root.ca.cert -infiles ${dir}/root.ca.csr

ln -s ./root.ca.cert "${dir}/current.ca.cert"
ln -s ./root.ca.key "${dir}/current.ca.key"
