.PHONY: installdeps srpm git_cfg_safe

installdeps:
	dnf -y install ${EXTRA_DNF_OPT} git gcc java-11-openjdk-devel libcurl-devel libxml2-devel maven redhat-rpm-config rpm-build rpmdevtools ruby \
		ruby-devel rubygem-rake rubygem-rake-compiler rubygem-rspec rubygems rubygems-devel

git_cfg_safe:
	# From git 2.35.2 we need to mark temporary directory, where the project is cloned to, as safe, otherwise
	# git commands won't work because of the fix for CVE-2022-24765
	git config --global --add safe.directory "$(shell pwd)"

srpm: installdeps git_cfg_safe
	./automation/build-copr.sh
	cp exported-artifacts/*.src.rpm $(outdir)
