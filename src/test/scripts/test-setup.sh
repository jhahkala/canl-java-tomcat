#!/bin/bash

SERVICE_CMD=`which service`
if [ x"$SERVICE_CMD" != x ] ;  then
	SERVICE_CMD="/sbin/service"
fi


# This script sets up a proper environment for the tests. This mainly consists of copying around certificates..

usage() {
 echo
 echo "Script for setting up the trustmanager test environment (copying around certs)."
 echo "You need to have created the certificates already with org.glite.security.test-utils"
 echo
 echo "test-setup.py --certdir <directory for test-utils certs>"
 echo
}

function removePassPhrase ()  {
 openssl rsa  -passin pass:changeit -in $certdir/$1.priv -out $certdir/$1_nopass.priv
}


while [ $# -gt 0 ]
do
 case $1 in
 --certdir | -c ) certdir=$2
  shift
  ;;
 --help | -help | --h | -h ) usage
  exit 0
  ;;
 --* | -* ) echo "$0: invalid option $1" >&2
  usage
  exit 1
  ;;
 *) break
  ;;
 esac
 shift
done

if [ x"$certdir" == x ] ; then
 usage
 exit 1
fi

echo "Copying host certificates"

cp $certdir/grid-security/hostcert.pem /etc/grid-security/tomcat-cert.pem
if [ $? -ne 0 ] ; then
 echo "Error copying host certificate"
 exit 1
fi
cp $certdir/grid-security/hostkey.pem /etc/grid-security/tomcat-key.pem
if [ $? -ne 0 ] ; then
 echo "Error copying host key"
 exit 1
fi

chown tomcat:tomcat /etc/grid-security/tomcat*

if [ $? -ne 0 ] ; then
    # for debian
	chown tomcat6:tomcat6 /etc/grid-security/tomcat*
	if [ $? -ne 0 ] ; then
 		echo "Error changing host credential permissions"
 		exit 1
 	fi
fi

echo "Generating short crl"
cd $certdir/trusted-ca
export CA_DIR=.
export CASROOT=$certdir
export DNS_HOSTNAME=fake.host.name

openssl ca -gencrl -crlhours 1 -out $CA_DIR/trusted.crl -config $CA_DIR/req_conf.cnf

cd -

echo "Copying CA certificates"
cp $certdir/grid-security/certificates/* /etc/grid-security/certificates/

#copy the generated crl, the -subject_has_old is supported only openssl >= 1.0, so detect that too
ca_hash=`openssl x509 -in $certdir/trusted-ca/trusted.cert -noout -subject_hash`
ca_hash2=`openssl x509 -in $certdir/trusted-ca/trusted.cert -noout -subject_hash_old 2>/dev/null`
OPENSSL1=$?

# copy the ca cert, twice if new SHA hashes are used.
cp $certdir/trusted-ca/trusted.crl /etc/grid-security/certificates/$ca_hash.r0
if [ $OPENSSL1 -eq 0 ]; then
    cp $certdir/trusted-ca/trusted.crl /etc/grid-security/certificates/$ca_hash2.r0
fi

echo "Removing passphrases from certificates"
while read LINE; do 
 removePassPhrase $LINE 
done < testcerts.txt

chmod 400 $certdir/trusted-certs/*priv


echo "Creating a correct trust chain for proxy proxies"
cat $certdir/trusted-certs/trusted_client.cert $certdir/trusted-certs/trusted_client.proxy.cert > $certdir/trusted-certs/trusted_client_proxy_chain
cat $certdir/trusted-certs/trusted_client.cert $certdir/trusted-certs/trusted_client.proxy_rfc_plen.cert $certdir/trusted-certs/trusted_client.proxy_rfc_plen.proxy_rfc.cert > $certdir/trusted-certs/trusted_client_rfc_proxy_chain


echo "put in example web page"
ls /etc/tomcat* |grep tomcat5
RES=$?
if [ $RES = 0 ]; then
    export TOMCAT_SERVICE=tomcat5
else
    export TOMCAT_SERVICE=tomcat6
fi

#tomcat webapp dir
mkdir /var/lib/${TOMCAT_SERVICE}/webapps/test
echo CANL_OK >/var/lib/${TOMCAT_SERVICE}/webapps/test/test.txt

SERVICE_CMD ${TOMCAT_SERVICE} restart
