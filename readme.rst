==========================================================================================
Certificate Authority
==========================================================================================

This project consists of three scripts

- create-root-ca.sh:
  Use this script to initialize a new certificate authority.

- create-intermediate-ca.sh:
  Use this script to create a new certificate that is allowed to sign certificate
  requests.

- create-leaf-cert.sh:
  Use this script to generate certificates and key pairs that can be used by clients such
  as web servers.

- set-current-ca.sh
  Use this script to set the certificate that should be used to sign newly created
  certificates. This is useful when you always want to use an intermediate certificate for
  subsequent requests.

Quick setup:

.. code-block:: terminal

    $ create-root-ca.sh --ca-home="example-$(date '+%Y')" --accept -o='Example NV'
    Main Ca Password []:
    ...
    $ create-intermediate-ca.sh --ca-home="example-XXXX" 'Example Authority G1'
    Main Ca Password []:
    ...
    $ set-current-ca.sh --ca-home="example-XXXX" 'Example Authority G1'
    $ create-leaf-cert.sh --ca-home="example-XXXX" \
    >     -cn='www.example.com' \
    >     -alt='m.example.com' -alt='example.com'
    Main Ca Password []:
    ...


Philosophy
==========================================================================================

This project allows you to simulate a ca environment for use in controlled server
environments. It gives you a root certificate, allows you to create multiple intermediate
certificates and create leaf certificates with a chosen common name and alternative names.

You are not limited to a single ca, you initialize a complete ca with
``create-root-ca.sh`` and provided it the home directory for that ca.

The structure for a ca is as follow:

.. code-block:: directory

    ./<ca-home>/
      |- certsdb/
      |- private/
      |    |- current.ca.cert -> root.ca.cert
      |    |- current.ca.key -> root.ca.cert
      |    |- root.ca.cert
      |    `- root.ca.key
      |- <group>/
      |- ...
      `- openssl.cnf

The ca certificates are kept in the ``private/`` sub folder, the self signed root
certificate is the ``root.ca.cert``. This is the certificate that should be installed on
systems that should accept certificate chains signed by that ca.

There is also a symlinked certificate and key in ``private/``. ``current.ca.cert`` points
to the ca certificate (root, or intermediate) that will be used to sign newly generated
certificates. This can be overwritten by providing ``--ca-cert`` to the creation scripts.

All crypto graphic material is kept under the ca home directory. This includes the private
keys that are generated for all certificates. Real world certificate authorities do not
operate in this way, but for the purposes of providing certificates to internally used
services this may have some advantages. For instance, even if a machine is nuked, are some
key is lost on the clients, we can recover by retrieving the required keys and
certificates from the 'ca'.

Any ca instance has a single main password to encrypt generated key material. In order to
use generated keys and certificates you can 'export' them from the ca with openssl,
providing a new password.

.. code-block:: terminal

    $ openssl rsa -in "./${ca_home}/${group}/${safe_cn}.key" -des3 -out exported.key

The scripts will try to resume work when previous attempts did not succeed or were
aborted. This is accomplished by detecting the presence of certain files. Situations may
occur in which files were created but left empty. These empty files will prevent the
scripts from properly resuming. To fix this run:

.. code-block:: terminal

    $ find "${ca_home}" -size 0 -delete


Create Root Ca
==========================================================================================

.. code-block:: terminal

    $ create-root-ca.sh --ca-home="example-$(date '+%Y')" -o='Example NV'

This will create a new directory, generate an openssl configuration file based on the
distinguished name information provided and create a new self signed root certificate. The
root certificate can be found at ``${ca_home}/private/root.ca.cert`` with the
corresponding key at ``${ca_home}/private/root.ca.key``.

The scripts needs a ``dn`` for the generated root certificate. These values can be
provided as flags to the script. When they are not provided the script will prompt the
user for them, suggesting a default when applicable.

For example:

.. code-block:: terminal

    $ create-root-ca.sh
    Country Name (2 letter code) [BE]:

The value between square brackets is the suggested default. If the value is left empty (by
only pressing enter) that default value between brackets will be used. After giving a
value or accepting the default the script will ask for the next value.

.. code-block:: terminal

    $ create-root-ca.sh
    Country Name (2 letter code) [BE]: NL
    State or Province Name (full name) [Limburg]:

After gathering the information for the ``dn``, the script will ask for the main password
of the ca. This password is required in other scripts that use the generated ca.

.. code-block:: terminal

    $ create-root-ca.sh
    ...
    Main Ca Password []:

In the last part of the process you are asked to review the root certificate and add it to
the internal database (located in ``${ca_hom}/certsdb``).

.. note::

    If you provided a commandline flag that the script does not know the script will print
    an error message and exit.

    .. code-block:: terminal

        $ create-root-ca.sh --unknown=value
        Unknown Argument --unknown
        $ echo $?
        1


Command Line Options
******************************************************************************************

:``--ca-home`` [default = './data/']:
    The home directory for the ca. This is the directory in which all required files are
    generated.

:``--days`` [default = "$(( 365 * 10 ))"]:
    The number of days the generated root certificate is valid.

:``--domain`` [default = 'example.com']:
    The domain where you plan to provide the crl lists. This will show up in the
    certificates `X509v3 CRL Distribution Points`. The domain will be turned into the
    following url: ``https://ca.${domain}/ca.crl``.

All parts of the dn can be provided with commandline flags (``-c``, ``-st``, ``-l``,
``-o``, ``-cn``). All flags that specify components to the distinguished name are prefixed
with a single dash (``-``).

:``-c`` [default = 'BE']:
    The country of the distinguished name (the ``/C=`` component).

:``-st`` [default = 'Limburg']:
    Province or state of the distinguished name (the ``/ST=`` component).

:``-l`` [default = 'Sint-Truiden']:
    The city or locality of the distinguished name (the ``/L=`` component).

:``-o`` *required !*:
    The organization name for the distinguised name (the ``/O=`` component).

:``-cn`` [default = "${organization} Root G1"]:
    The common name for the distinguished name (the ``/CN=`` component).

When no value is provided on the command line the script will ask for a value. It will
show the default, if you leave the field blank the default will be used. If you want to
accept the default values automatically you can use ``--accept``

:``--accept``:
    Accept the default values for the ``dn`` without asking for confirmation input. This
    only works for values that have a default value. If ``-o`` is not provided on the
    commandline the script will still ask for an organization name.


Key Rollover
******************************************************************************************

At one point a new root certificate may need to be generated. This is in effect a
completely new ca. For smoother transitions some of the steps in [1] can be followed.

- Generate a new ca with a new ``--ca-home``
- Install the new root on all devices that trust the old root
- Reissue all valid certificates issued by the old ca
- Distribute the newly issued certificates
- Stop using the old root
  - use the proper crl mechanisms (this requires hosting the crl on the url)
  - let it expire
  - remove the root from all devices that trust it

It could help to follow a scheme when picking names for the ca home directories. The ca
directories should indicate the generation or starting point. For instance ``company-g1``,
``company-g2``, ... or ``company-2020``, ``company-2030`` ... .

[1] https://tools.ietf.org/html/rfc6489


Create Intermediate Ca
==========================================================================================

.. code-block:: terminal

    $ create-intermediate-ca.sh --ca-home="example-XXXX" -cn="Example Authority G1"
    $ create-intermediate-ca.sh --ca-home="example-XXXX" "Example Authority G["

This will create a new certificate that is allowed to issue other certificates. The
generated certificate can be found at ``${ca_home}/private/``. The file name of the
certificate is derived from the ``cn``. All spaces and periods are substituted with an
underscore (``_``). For our example the certificate would be located at
``example-XXX/private/Example_Authority_G1.ca.cert`` with the corresponding key located at
``example-XXX/private/Example_Authority_G1.ca.key``.

You can create ca certificates certificates further down by providing:

.. code-block:: terminal

    $ create-intermediate-ca.sh --ca-home="example-XXXX" \
    >     -ca-cert="Example Authority G1" \
    >     -cn="Example Foo Authority G1"
    ...
    $ create-intermediate-ca.sh --ca-home="example-XXXX" \
    >     -ca-cert="Example Authority G1" \
    >     -cn="Example Bar Authority G1"
    ...
    $ create-intermediate-ca.sh --ca-home="example-XXXX" \
    >     -ca-cert="Example Authority G1" \
    >     -cn="Example Baz Authority G1"
    ...

This will create a ca structure as followed:

.. mermaid::

    graph TD;
        root[Example Root G1]
        ca[Example Authority G1 ]
        foo[Example Foo Authority G1]
        bar[Example Bar Authority G1]
        baz[Example Baz Authority G1]

        root --> ca
        ca --> foo
        ca --> bar
        bar --> baz

The intermediate certificates will automatically take on the subject of the root
certificate. Only the ``cn`` portion will change.

.. code-block:: terminal

    $ openssl x509 -subject -noout -in example-XXXX/private/Example_Authority_G1.ca.cert
    subject= /C=BE/ST=Limburg/L=Sint-Truiden/O=Example/CN=Example Authority G1


Command Line Options
******************************************************************************************

:``--ca-home`` [default = './data/']:
    The home directory for the ca. This is the directory in which the generated
    intermediate ca certificate will be generated. This should be a directory that is
    generated with the ``create-root-ca.sh``.

:``--ca-cert`` [default = 'current']:
    specify with which certificate the newly generated certificate should be signed. The
    value of this option can be the ``cn`` of one of the existing intermediate
    certificates, or it can be 'root'.

:``--days`` [default = '$(( 365 * 5 ))':
    The number of days the generated certificate is valid.

Parts of the ``dn`` for the generated certificate are forced to be the same as those in
the root certificate. Only the ``cn`` can vary. This can be specified as the value of a
commandline flag, or as the last argument to the command.

:``-cn`` *required !*:
    The common name for the distinguished name (the ``/CN=`` component).


Create Certificate
==========================================================================================

.. code-block:: terminal

    $ create-leaf-cert.sh --ca-home="example-XXXX" -cn="www.example.com"
    $ create-leaf-cert.sh --ca-home="example-XXXX" "www.example.com"

The script generates a new certificate signed by the default ca certificate active for the
ca. The location of the generated certificate is
``${ca_home}/${group}/${cn_file_name}.cert``.  The file name is derived from the actual
``cn`` by replacing all spaces and periods with an underscore. The group of the
certificate defaults to ``main``.

To put the certificate into a different group you can specify the group when creating the
certificate:

.. code-block:: terminal

    $ create-leaf-cert.sh --ca-home="example-XXXX" --group='www-2020-q1' -cn="www.example.com"

The script also generates a p12 and a 'chain' file that contains all the certificates in
the chain including the root certificate. Nginx for instance requires a cert file that
contains the chain. This file can be created by combining the certificate and the chain
file:

.. code-block:: terminal

    $ cat "${ca_home}/${group}/${cn}.cert" "${ca_home}/${group}/${cn}.chain" > "${cn}.cert"

Browsers may automatically redirect requests from ``www.domain.ext`` to ``domain.ext``, or
at least validate against the certificate against the later. If the ``cn`` is contains the
``www`` subdomain the certificate may not be considered valid. This can be fixed by
providing one of them as an alternative name.

.. code-block:: terminal

    $ create-leaf-cert.sh --ca-home="example-XXXX" \
    >     -cn="www.example.com" \
    >     -alt="example.com"

This can also be used to create star certificates

.. code-block:: terminal

    $ create-leaf-cert.sh --ca-home="example-XXXX" \
    >     -cn="www.example.com" \
    >     -alt=".*example.com" \
    >     -alt="example.com"

The generated certificates will automatically take on the subject of the singing
certificate. Only the ``cn`` portion will change.

.. code-block:: terminal

    $ openssl x509 -subject -noout -in example-XXXX/private/Example_Authority_G1.ca.cert
    subject= /C=BE/ST=Limburg/L=Sint-Truiden/O=Example/CN=Example Authority G1


Command Line Options
******************************************************************************************

:``--ca-home`` [default = './data/']:
    The home directory for the ca. This is the directory in which the generated
    intermediate ca certificate will be generated. This should be a directory that is
    generated with the ``create-root-ca.sh``.

:``--ca-cert`` [default = 'current']:
    specify with which certificate the newly generated certificate should be signed. The
    value of this option can be the ``cn`` of one of the existing intermediate
    certificates, or it can be 'root'.

:``--group`` [default = 'main']:
    The group of the certificate. This allows you to organize the generated certificates
    into logical units. For instance: ``'www/g1'``, ``'brokers/2018``, ... .

:``--days`` [default = '$(( 365 * 1 ))':
    The number of days the generated certificate is valid.

Parts of the ``dn`` for the generated certificate are forced to be the same as those in
the signing certificate. Only the ``cn`` can vary. This can be specified as the value of a
commandline flag, or as the last argument to the command.

:``-cn`` *required !*:
    The common name for the distinguished name (the ``/CN=`` component).

:``-alt`` optional ?:
    An alternative name for the certificate, can be provided multiple times. The value of
    ``-cn`` is also added to the list of alternative names.


Key Rollover
******************************************************************************************

When a certificate is about to expire you can create a new certificate with the same
``cn``. You will also get a new private key which you'll need to redistribute together
with the certificate (you can also use the p12 instead).

Since the scripts will try to recover from previous failed generation attempts, the new
certificate will need to be in a new group. For this reason you may want to put generated
leaf certificates in a group that indicates when it was created or when it will expire.
The idea is similar to the naming of intermediate certificate ``cn`` s.


Example Scenario
==========================================================================================

You have a bunch of micro services that all expose a web api over ssl on your internal
network. You wont to expose the api on ``name.service.example.com``.

.. code-block:: terminal

    $ export sca='Example Services CA G1'
    $ export vca='Example VPN CA G1'

    $ create-root-ca.sh --ca-home='example-g1' --o 'Example' --accept
    $ create-intermediate-ca.sh --ca-home='example-g1' --ca-cert='root' -cn="${sca}"
    $ create-intermediate-ca.sh --ca-home='example-g1' --ca-cert='root' -cn="${vca}"
    $ cerate-leaf-cert.sh --ca-home='example-g1' --ca-cert="${sca}" -cn='a.services.example.com'
    $ cerate-leaf-cert.sh --ca-home='example-g1' --ca-cert="${sca}" -cn='b.services.example.com'
    $ cerate-leaf-cert.sh --ca-home='example-g1' --ca-cert="${vca}" -cn='client1'
