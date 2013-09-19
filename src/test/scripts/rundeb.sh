#!/bin/bash
apt-get -y install git
git clone https://github.com/jhahkala/canl-java-tomcat.git
cd canl-java-tomcat/src/test/scripts
./debtest.sh