#!/bin/bash

# Basic stuff

which sed
if [ $? -ne 0 ] ; then
    echo "sed not found... exiting"
    exit 2
fi

#detect redhad version, mainly for tomcat version
grep "Scientific Linux SL release 5" /etc/redhat-release
if [ $? -eq 0 ] ; then
    echo "This is sl5 with tomcat 5"
    tomcat_version=5
    os=sl5
else
    grep "Scientific Linux release 6" /etc/redhat-release
    if [ $? -eq 0 ] ; then
	echo "This is sl6 with tomcat 6"
	tomcat_version=6
	os=sl6
    else
	echo "Assuming this is debian with tomcat 6"
	tomcat_version=6
	os=deb6
    fi
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

cd ~

rpm --import http://emisoft.web.cern.ch/emisoft/dist/EMI/3/RPM-GPG-KEY-emi

wget --no-check-certificate http://repository.egi.eu/sw/production/cas/1/current/repo-files/egi-trustanchors.repo
if [ x${os} == "xsl5" ] ; then
    wget http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl5/x86_64/base/emi-release-3.0.0-2.el5.noarch.rpm
	yum -y localinstall emi-release-3.0.0-2.el5.noarch.rpm
	wget https://github.com/jhahkala/canl-java-tomcat/blob/gh-pages/packages/canl-java-tomcat-0.1.13-1.noarch.rpm?raw=true
elif  [ x${os} == "xsl6" ] ; then
	wget http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl6/x86_64/base/emi-release-3.0.0-2.el6.noarch.rpm
	yum -y localinstall emi-release-3.0.0-2.el6.noarch.rpm
	wget https://github.com/jhahkala/canl-java-tomcat/blob/gh-pages/packages/canl-java-tomcat-0.1.13-1.el6.noarch.rpm?raw=true
fi

#get the canl-java-tomcat repo
#cat etics-*.repo | sed s/'protect=1'/'priority=30\nprotect=1'/ > canl-java-tomcat.repo
#rm etics-*.repo
#mv -f etics-registered-build-by-id-protect.repo  ~/etics-registered-build-by-id-protect.repo
# Gotta make sure the repositories are enabled!
#sed -i 's/\/EMI\/1\/sl/\/EMI\/2\/RC\/sl/g' /etc/yum.repos.d/emi1-base.repo
#sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/emi1-base.repo
#sed -i 's/\/EMI\/1\/sl/\/EMI\/2\/RC\/sl/g' /etc/yum.repos.d/emi1-third-party.repo
#sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/emi1-third-party.repo
#sed -i 's/\/EMI\/1\/sl/\/EMI\/2\/RC\/sl/g' /etc/yum.repos.d/emi1-updates.repo
#sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/emi1-updates.repo

CMD="yum install -y glite-yaim-core xml-commons-apis fetch-crl ca-policy-egi-core git cvs emacs"
echo $CMD 
$CMD >/root/yum.log 2>&1 
if [ $? -ne 0 ] ; then
    echo "package installation failed... exiting"
    exit 2;
fi

CMD="yum localinstall -y canl-java-tomcat-*"
echo $CMD 
$CMD >/root/yum.log 2>&1 
if [ $? -ne 0 ] ; then
    echo "package installation failed... exiting"
    exit 2;
fi


cd ~

#clean up tomcat logs
/sbin/service tomcat${tomcat_version} stop
rm -f /var/log/tomcat${tomcat_version}/*

# check out the test cert generation stuff and generate test certs
export CVSROOT=":pserver:anonymous@glite.cvs.cern.ch:/cvs/glite"
export CVS_RSH=ssh

if [ ! -d /root/certs ] ; then
	git clone https://github.com/jhahkala/test-certs.git
    cd test-certs
    bin/generate-test-certificates.sh --all --voms /root/certs >/root/certs.log 2>&1

    cd ~
fi

#update crls
/usr/sbin/fetch-crl

# temporary fixes for the rpm problems, remove when the rpm is fixed
#ln -snf /usr/share/java/bcprov-1.46.jar /var/lib/tomcat${tomcat_version}/server/lib/bcprov.jar
#rm -rf /var/lib/tomcat${tomcat_version}/server/lib/\[bc*
#mv /var/lib/tomcat${tomcat_version}/server/lib/\[canl-java-tomcat\].jar /var/lib/tomcat${tomcat_version}/server/lib/canl-java-tomcat.jar

# temp fix for sl6, before the jar linking is fixed
#if  [ x${os} == "xsl6" ] ; then
#    ln -snf /usr/share/java/canl.jar /usr/share/tomcat6/lib/canl.jar
#fi

#cd /usr/share/java
#jar -i jakarta-commons-modeler-1.1.jar
cd ~/canl-java-tomcat/src/test/scripts

# temporary fix for yaim, remove when yaim is updated
cp config_secure_tomcat /opt/glite/yaim/functions/
cp site-info.pre /opt/glite/yaim/defaults/

# config default with yaim 
echo "#" >site-info.def
echo y|/opt/glite/yaim/bin/yaim -r -s site-info.def -f config_secure_tomcat >/root/config.log 2>&1

./test-setup.sh --certdir /root/certs/

/sbin/service tomcat${tomcat_version} start
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

