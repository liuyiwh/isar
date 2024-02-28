# This software is a part of ISAR.
# Copyright (C) 2017-2019 Siemens AG
# Copyright (C) 2021 Siemens Mobility GmbH
#
# SPDX-License-Identifier: MIT

CHANGELOG_V ??= "${PV}"
DPKG_ARCH ??= "any"
DEBIAN_BUILD_DEPENDS ??= ""
DEBIAN_DEPENDS ??= ""
DEBIAN_PROVIDES ??= ""
DEBIAN_REPLACES ??= ""
DEBIAN_CONFLICTS ??= ""
DEBIAN_MULTI_ARCH ??= "no"
DEBIAN_COMPAT ??= "10"
DESCRIPTION ??= "must not be empty"
MAINTAINER ??= "Unknown maintainer <unknown@example.com>"

deb_add_changelog() {
	changelog_v="${CHANGELOG_V}"
	timestamp=3600
	if [ -f ${S}/debian/changelog ]; then
		if [ ! -f ${WORKDIR}/changelog.orig ]; then
			cp ${S}/debian/changelog ${WORKDIR}/changelog.orig
		fi
		# we have a non auto-generated original changelog
		if [ -s ${WORKDIR}/changelog.orig ]; then
			orig_version=$(dpkg-parsechangelog -l ${WORKDIR}/changelog.orig -S Version)
			changelog_v=$(echo "${changelog_v}" | sed 's/<orig-version>/'${orig_version}'/')
			orig_date=$(dpkg-parsechangelog -l ${WORKDIR}/changelog.orig -S Date)
			orig_seconds=$(date --date="${orig_date}" +'%s')
			timestamp=$(expr ${orig_seconds} + 42)
		fi
	fi

	date=$(LANG=C date -R -d @${timestamp})
	cat <<EOF > ${S}/debian/changelog
${BPN} (${changelog_v}) UNRELEASED; urgency=low

  * generated by Isar

 -- ${MAINTAINER}  ${date}
EOF
	# ensure that we always start with the orig version of the
	# changelog on repeated invocations (e.g. on partial rebuilds)
	touch ${WORKDIR}/changelog.orig
	if [ -s ${WORKDIR}/changelog.orig ]; then
		# prepend our entry to the original changelog
		echo >> ${S}/debian/changelog
		cat ${WORKDIR}/changelog.orig >> ${S}/debian/changelog
	fi

	if [ -f ${WORKDIR}/changelog ]; then
		latest_version=$(dpkg-parsechangelog -l ${WORKDIR}/changelog -S Version)
		if [ "${latest_version}" = "${changelog_v}" ]; then
			# entry for our version already there, use unmodified
			rm ${S}/debian/changelog
		else
			# prepend our entry to an existing changelog
			echo >> ${S}/debian/changelog
		fi
		cat ${WORKDIR}/changelog >> ${S}/debian/changelog
	fi
}


deb_create_control() {
	cat << EOF > ${S}/debian/control
Source: ${BPN}
Section: misc
Priority: optional
Standards-Version: 3.9.6
Maintainer: ${MAINTAINER}
Build-Depends: debhelper-compat (= ${DEBIAN_COMPAT}), ${DEBIAN_BUILD_DEPENDS}

Package: ${BPN}
Architecture: ${DPKG_ARCH}
Depends: ${DEBIAN_DEPENDS}
Provides: ${DEBIAN_PROVIDES}
Replaces: ${DEBIAN_REPLACES}
Conflicts: ${DEBIAN_CONFLICTS}
Multi-Arch: ${DEBIAN_MULTI_ARCH}
Description: ${DESCRIPTION}
EOF
}

deb_compat() {
	bbwarn "Function deb_compat is deprecated and the content was\nreplaced with a dependency to debhelper-compat!"
}

DH_FIXPERM_EXCLUSIONS = \
    "${@' '.join(['-X ' + x for x in \
                  (d.getVar('PRESERVE_PERMS', False) or '').split()])}"

deb_create_rules() {
	cat << EOF > ${S}/debian/rules
#!/usr/bin/make -f

override_dh_fixperms:
	dh_fixperms ${DH_FIXPERM_EXCLUSIONS}

%:
	dh \$@
EOF
	chmod +x ${S}/debian/rules
}

deb_debianize() {
	install -m 755 -d ${S}/debian

	# create the control-file if there is no control-file in WORKDIR
	if [ -f ${WORKDIR}/control ]; then
		install -v -m 644 ${WORKDIR}/control ${S}/debian/control
	else
		deb_create_control
	fi
	# create rules if WORKDIR does not contain a rules-file
	if [ -f ${WORKDIR}/rules ]; then
		install -v -m 755 ${WORKDIR}/rules ${S}/debian/rules
	else
		deb_create_rules
	fi
	# prepend a changelog-entry unless an existing changelog file already
	# contains an entry with CHANGELOG_V
	deb_add_changelog

	# copy all hooks from WORKDIR into debian/, hooks are not generated
	for t in pre post
	do
		for a in inst rm
		do
			if [ -f ${WORKDIR}/${t}${a} ]; then
				install -v -m 755 ${WORKDIR}/${t}${a} \
					${S}/debian/${t}${a}
			fi
		done
	done
}
