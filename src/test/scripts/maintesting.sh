#!/bin/bash

# Basic stuff

which sed
if [ $? -ne 0 ] ; then
    echo "sed not found... exiting"
    exit 2;
fi

# setup repositories
yum install -y yum-conf-epel
cd /etc/yum.repos.d
# 
# Get rid of repos that might mess up stuff

rm -f adobe.repo atrpms.repo dag.repo epel-testing.repo \
         sl-contrib.repo sl-debuginfo.repo sl-fastbugs.repo \
         sl-srpms.repo sl-testing.repo \
         glite-rip-3.* non-glite-rip-3.* \
         egi-trustanchors.repo internal.repo CERN-only.repo

wget --no-check-certificate http://repository.egi.eu/sw/production/cas/1/current/repo-files/egi-trustanchors.repo
wget --no-check-certificate http://eticssoft.web.cern.ch/eticssoft/mock/emi-3-rc-sl5.repo

wget --no-check-certificate http://emisoft.web.cern.ch/emisoft/dist/EMI/2/RPM-GPG-KEY-emi
mv RPM-GPG* /etc/pki/rpm-gpg/
#get the canl-java-tomcat repo
#cat etics-registered-build-by-id-protect.repo | sed s/'protect=1'/'priority=30\nprotect=1'/ > trustmanager.repo
#mv -f etics-registered-build-by-id-protect.repo  ~/etics-registered-build-by-id-protect.repo
# Gotta make sure the repositories are enabled!
#sed -i 's/\/EMI\/1\/sl/\/EMI\/2\/RC\/sl/g' /etc/yum.repos.d/emi1-base.repo
#sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/emi1-base.repo
#sed -i 's/\/EMI\/1\/sl/\/EMI\/2\/RC\/sl/g' /etc/yum.repos.d/emi1-third-party.repo
#sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/emi1-third-party.repo
#sed -i 's/\/EMI\/1\/sl/\/EMI\/2\/RC\/sl/g' /etc/yum.repos.d/emi1-updates.repo
#sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/emi1-updates.repo

CMD="yum install -y canl-java-tomcat glite-yaim-core commons-xml-apis fetch-crl ca-policy-egi-core git cvs emacs"
echo $CMD; $CMD
if [ $? -ne 0 ] ; then
    echo "package installation failed... exiting"
    exit 2;
fi

cd ~

#clean up tomcat logs
/sbin/service tomcat5 stop
rm -f /var/log/tomcat5/*

# check out the test cert generation stuff and generate test certs
export CVSROOT=":pserver:anonymous@glite.cvs.cern.ch:/cvs/glite"
export CVS_RSH=ssh

if [ ! -d /root/certs ] ; then
    cvs co org.glite.security.test-utils
    cd org.glite.security.test-utils
    bin/generate-test-certificates.sh --all --voms /root/certs
    cd ~
fi

#update crls
/usr/sbin/fetch-crl

# temporary fixes for the rpm problems, remove when the rpm is fixed
ln -snf /usr/share/java/bcprov-1.46.jar /var/lib/tomcat5/server/lib/bcprov.jar
rm -rf /var/lib/tomcat5/server/lib/\[bc*
mv /var/lib/tomcat5/server/lib/\[canl-java-tomcat\].jar /var/lib/tomcat5/server/lib/canl-java-tomcat.jar

cd /usr/share/java
jar -i jakarta-commons-modeler-1.1.jar
cd ~

# temporary fix for yaim, remove when yaim is updated
cp config_secure_tomcat /opt/glite/yaim/functions/
cp site-info.pre /opt/glite/yaim/defaults/

# config default with yaim 
echo "#" >site-info.def
/opt/glite/yaim/bin/yaim -r -s site-info.def -f config_secure_tomcat

git clone https://github.com/jhahkala/canl-java-tomcat.git
cd canl-java-tomcat/src/test/scripts

./test-setup.sh --certdir /root/certs/

/sbin/service tomcat5 start
sleep 15

echo "#run following commands:"
echo "#------------------------------------------------------"
echo cd ~/canl-java-tomcat/src/test/scripts
echo ./certificate-tests.sh --certdir /root/certs/

echo #set clock forward to make CRLs expire
echo "date --set='+70 minutes'"
echo ./certificate-tests+1h.sh --certdir /root/certs/

cd ~/canl-java-tomcat/src/test/scripts
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

