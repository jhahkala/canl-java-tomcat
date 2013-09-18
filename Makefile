##
# Copyright (c) Members of the EGEE Collaboration. 2006-2010.
# See http://www.eu-egee.org/partners/ for details on the copyright holders.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##

name=canl-java-tomcat

version=0.1.18
release=1

prefix=/
deb_name=lib$(name)

spec_file=fedora/$(name).spec
maven_settings_file=maven-settings.xml

rpmbuild_dir=$(CURDIR)/rpmbuild
debbuild_dir = $(CURDIR)/debbuild
tmp_dir=$(CURDIR)/tmp
# ETICS directories
tgz_dir=$(CURDIR)/tgz
rpm_dir=$(CURDIR)/RPMS
deb_dir=$(CURDIR)/debs

.PHONY: clean spec dist package install srpm rpm deb deb-src

all: package


clean:
	rm -rf target $(rpmbuild_dir) $(debbuild_dir) $(tmp_dir) *.tar.gz $(tgz_dir) $(rpm_dir) $(deb_dir) $(spec_file)


spec:
	@echo "Setting version and release in spec file: $(version)-$(release)"
	sed -e 's#@@VERSION@@#$(version)#g' -e 's#@@RELEASE@@#$(release)#g' $(spec_file).in > $(spec_file)


dist: spec
	@echo "Package the sources..."
	test ! -d $(tmp_dir) || rm -fr $(tmp_dir)
	mkdir -p $(tmp_dir)/$(name)-$(version)
	cp Makefile README.md pom.xml maven-settings.xml $(tmp_dir)/$(name)-$(version)
	cp -r debian fedora $(tmp_dir)/$(name)-$(version)
	cp -r doc $(tmp_dir)/$(name)-$(version)
	cp -r src $(tmp_dir)/$(name)-$(version)
	test ! -f $(name)-$(version).tar.gz || rm $(name)-$(version).tar.gz
	tar -C $(tmp_dir) -czf $(name)-$(version).tar.gz $(name)-$(version)


package: spec
	@echo "Build with maven"
	mvn -B -s $(maven_settings_file) package


install:
	@echo "Install binary in $(DESTDIR)$(prefix)"
	mkdir -p $(DESTDIR)$(prefix)/usr/share/java
	cp target/$(name)-$(version).jar $(DESTDIR)$(prefix)/usr/share/java
	@echo link jar to unversioned version
	cd $(DESTDIR)$(prefix)/usr/share/java/;	ln -snf $(name)-$(version).jar $(name).jar
	chmod -f 0644 $(DESTDIR)$(prefix)/usr/share/java/$(name)-$(version).jar
	mkdir -p $(DESTDIR)$(prefix)/usr/share/doc/$(name)-$(version)
	cp -r doc/* $(DESTDIR)$(prefix)/usr/share/doc/$(name)-$(version)
	chmod -Rf 0644 $(DESTDIR)$(prefix)/usr/share/doc/$(name)-$(version)/*


pre_rpmbuild:
	test -f $(name)-$(version).tar.gz || make dist
	@echo "Preparing for rpmbuild in $(rpmbuild_dir)"
	mv $(name)-$(version).tar.gz $(name)-$(version).src.tar.gz
	mkdir -p $(rpmbuild_dir)/BUILD $(rpmbuild_dir)/RPMS $(rpmbuild_dir)/SOURCES $(rpmbuild_dir)/SPECS $(rpmbuild_dir)/SRPMS
	cp $(name)-$(version).src.tar.gz $(rpmbuild_dir)/SOURCES/$(name)-$(version).tar.gz


srpm: pre_rpmbuild
	@echo "Building SRPM in $(rpmbuild_dir)"
	rpmbuild --nodeps -v -bs $(spec_file) --define "_topdir $(rpmbuild_dir)"


rpm: pre_rpmbuild
	@echo "Building RPM/SRPM in $(rpmbuild_dir)"
	rpmbuild --nodeps -v -ba $(spec_file) --define "_topdir $(rpmbuild_dir)"


pre_debbuild:
	test -f $(name)-$(version).tar.gz || make dist
	@echo "Prepare for Debian building in $(debbuild_dir)"
	mv $(name)-$(version).tar.gz $(deb_name)-$(version).src.tar.gz
	mkdir -p $(debbuild_dir)
	cp $(deb_name)-$(version).src.tar.gz $(debbuild_dir)/$(deb_name)_$(version).orig.tar.gz
	tar -C $(debbuild_dir) -xzf $(deb_name)-$(version).src.tar.gz


deb: pre_debbuild
	@echo "Building Debian package in $(debbuild_dir)"
	cd $(debbuild_dir)/$(name)-$(version) && debuild -us -uc 


deb-src: pre_debbuild
	@echo "Building Debian source package in $(debbuild_dir)"
	cd $(debbuild_dir) && dpkg-source -b $(name)-$(version)

