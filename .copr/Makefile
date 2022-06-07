.PHONY: installdeps srpm

installdeps:
	dnf -y install ${EXTRA_DNF_OPT} git gcc java-11-openjdk-devel libcurl-devel libxml2-devel maven redhat-rpm-config rpm-build rpmdevtools ruby \
		ruby-devel rubygem-rake rubygem-rake-compiler rubygem-rspec rubygems rubygems-devel

srpm: installdeps
	./automation/build-copr.sh
	cp exported-artifacts/*.src.rpm $(outdir)
