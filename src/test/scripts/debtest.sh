#!/bin/bash

wget -q -O - https://dist.eugridpma.info/distribution/igtf/current/GPG-KEY-EUGridPMA-RPM-3 | apt-key add -

echo "#### EGI Trust Anchor Distribution ####" >> /etc/apt/sources.list
echo deb http://repository.egi.eu/sw/production/cas/1/current egi-igtf core >> /etc/apt/sources.list

apt-get update
apt-get install ca-policy-egi-core

wget -q   -O - http://emisoft.web.cern.ch/emisoft/dist/EMI/3/RPM-GPG-KEY-emi | apt-key add -

wget http://emisoft.web.cern.ch/emisoft/dist/EMI/3/debian/dists/squeeze/main/binary-amd64/emi-release_3.0.0-2.deb6.1_all.deb

dpkg -i emi-release_3.0.0-2.deb6.1_all.deb

apt-get install git
apt-get install tomcat6
apt-get install libcanl-java-tomcat

cp server.xml log4j-trustmanager.properties /etc/tomcat6

if [ ! -d /root/certs ] ; then
	git clone https://github.com/jhahkala/test-certs.git
    cd test-certs
    bin/generate-test-certificates.sh --all --voms /root/certs >/root/certs.log 2>&1

    cd ~
fi

cd ~/canl-java-tomcat/src/test/scripts

./test-setup.sh --certdir /root/certs/

service tomcat6 start
sleep 15
./certificate-tests.sh --certdir /root/certs/ 
RES=$?
if [ $RES -ne 0 ]; then
    echo Certificate tests failed
    exit 1
fi

echo #set clock forward to make CRLs expire
date --set='+70 minutes'
date --set='+70 minutes'
sleep 30
./certificate-tests-1h.sh --certdir /root/certs/
RES=$?
if [ $RES -ne 0 ]; then
    echo certificate +1h tests failed
    exit 1
fi
