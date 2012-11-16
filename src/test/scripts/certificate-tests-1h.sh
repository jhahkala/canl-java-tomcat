#!/bin/sh

# Test connecting with a number of different certificates
# This assumes that the certificates were created with
# org.glite.security.test-utils

#config variables
#tomcat host and port
export HOST=`hostname -f`:8443
echo host is $HOST
#tomcat service (for service xxxx restart)
rpm -qa |grep tomcat5
RES=$?
if [ $RES = 0 ]; then
    export TOMCAT_SERVICE=tomcat5
else
    export TOMCAT_SERVICE=tomcat6
fi
#end of config variables

SUCCESS=1
FAIL=0

function myexit() {
  if [ -f /etc/grid-security/certificates/$ca_hash.r0.bak ] ; then
    mv /etc/grid-security/certificates/$ca_hash.r0.bak /etc/grid-security/certificates/$ca_hash.r0
  fi

  if [ $1 -ne 0 ]; then
    echo " *** something went wrong *** "
    echo " *** test NOT passed *** "
    exit $1
  else
    echo ""
    echo "    === test PASSED === "
  fi
   
  exit 0
}

function myecho()
{
  echo "#trustmanager certificate tests# $1"
}

usage() {
 echo
 echo "Test different certificates against trustmanager"
 echo "This test assumes that you're using certificates"
 echo "by org.glite.security.test-utils"
 echo "Usage:"
 echo "======"
 echo "certificate-tests.sh --certdir <directory for test-utils certs>"
 echo ""
}

function test_cert() {
 KEY=$1
 CERT=$2
 OUTCOME=$3

 if [ x"$4" != x ] ;  then
  CA_CMD="--cacert $4"
 else
  CA_CMD=""
 fi


echo "curl -v -s -S --cert $CERT --key $KEY $CA_CMD --capath /etc/grid-security/certificates/ https://${HOST}/trustmanager-test/services/EchoServ\
ice?method=getAttributes|&grep -v \"failed to load .* from CURLOPT_CAPATH\""
curl -v -s -S --cert $CERT --key $KEY $CA_CMD --capath /etc/grid-security/certificates/ https://${HOST}/trustmanager-test/services/EchoServ\
ice?method=getAttributes | grep -v "failed to load .* from CURLOPT_CAPATH"|grep "Your final certificate subject is"
# openssl s_client -key $KEY -cert $CERT -CApath /etc/grid-security/certificates $CA_CMD -connect $HOST < input.txt  2>/dev/null |grep "(ok)" 
 RES=$?

 if [ $OUTCOME -eq $SUCCESS ] ; then 
  if [ $RES -ne 0 ] ; then
   myecho "Error, testing with $CERT failed when it should have suceeded"
   myexit 1
  fi
 else
  if [ $RES -eq 0 ] ; then
   myecho "Error, testing with $CERT succeeded when it should have failed"
   myexit 1
  fi
 fi
 
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

ca_hash=`openssl x509 -in $certdir/trusted-ca/trusted.cert -noout -subject_hash`
ca_hash2=`openssl x509 -in $certdir/trusted-ca/trusted.cert -noout -subject_hash_old`
OPENSSL1=$?


#Check that the CRL has expired
exp=`openssl crl -in /etc/grid-security/certificates/$ca_hash.r0 -noout -nextupdate | cut -f2 -d = `
whene=`date -d "$exp" +%s`
now=`date +%s`

if [ $now -lt $whene ] ; then
 echo "CRL not yet expired, CRL will expire at $exp"
 exit 0
fi

myecho "Testing with normal certificate, when CA crl should have expired"
test_cert $certdir/trusted-certs/trusted_client_nopass.priv $certdir/trusted-certs/trusted_client.cert $FAIL
myecho "Test passed"
echo ""
myecho "Moving CRL"
mv /etc/grid-security/certificates/$ca_hash.r0 /etc/grid-security/certificates/$ca_hash.r0.bak
if [ $OPENSSL1 -eq 0 ]; then
    mv /etc/grid-security/certificates/$ca_hash2.r0 /etc/grid-security/certificates/$ca_hash2.r0.bak
fi

myecho "Restarting tomcat"
/sbin/service $TOMCAT_SERVICE restart

sleep 15

myecho "Testing with normal certificate, without CA crl"
test_cert $certdir/trusted-certs/trusted_client_nopass.priv $certdir/trusted-certs/trusted_client.cert $FAIL
myecho "Test passed"
myecho "Moving CRL back"
mv /etc/grid-security/certificates/$ca_hash.r0.bak /etc/grid-security/certificates/$ca_hash.r0
if [ $OPENSSL1 -eq 0 ]; then
    mv /etc/grid-security/certificates/$ca_hash2.r0.bak /etc/grid-security/certificates/$ca_hash2.r0
fi

myecho "Restarting tomcat"
/sbin/service $TOMCAT_SERVICE restart

myexit 0
