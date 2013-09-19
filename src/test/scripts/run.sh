yum install -y yum-conf-epel
yum -y install git
git clone https://github.com/jhahkala/canl-java-tomcat.git
cd canl-java-tomcat/src/test/scripts
./maintesting.sh
