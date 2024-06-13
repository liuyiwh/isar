# Distro kernel dummy package
#
# This software is a part of ISAR.
# Copyright (c) Siemens AG, 2018
#
# SPDX-License-Identifier: MIT

python() {
    if ("class-native" or "class-compat") in d.getVar("OVERRIDES").split(":"):
        return

    distro_kernels = d.getVar('DISTRO_KERNELS') or ""
    for kernel in distro_kernels.split():
        d.appendVar('PROVIDES', ' linux-image-' + kernel)
        d.appendVar('PROVIDES', ' linux-headers-' + kernel)
        d.appendVar('PROVIDES', ' linux-kbuild-' + kernel)
    if d.getVar('KERNEL_IMAGE_PKG'):
        d.appendVar('PROVIDES', ' ' + d.getVar('KERNEL_IMAGE_PKG'))
    if d.getVar('KERNEL_HEADERS_PKG'):
        d.appendVar('PROVIDES', ' ' + d.getVar('KERNEL_HEADERS_PKG'))
}

inherit multiarch

inherit dpkg-raw
DEBIAN_BUILD_DEPENDS = "linux-image-${KERNEL_NAME}"

do_prepare_build:prepend() {
    mkdir -p ${D}/usr/lib/${PN}
}

do_prepare_build:append() {
    cat <<EOF >> ${S}/debian/rules

override_dh_auto_build:
EOF
    for dtb in ${DTB_FILES}; do
        mkdir -p ${D}/usr/lib/${PN}/$(dirname ${dtb})
        ppdir=${PP}/image/usr/lib/${PN}/$(dirname ${dtb})
        cat <<EOF >> ${S}/debian/rules
	find /usr/lib/linux-image* -path "*${dtb}" -print -exec cp {} ${ppdir} \;
EOF
    done
}

do_deploy[dirs] = "${DEPLOY_DIR_IMAGE}"
do_deploy() {
    for dtb in ${DTB_FILES}; do
        dpkg --fsys-tarfile ${WORKDIR}/${PN}_${CHANGELOG_V}_${PACKAGE_ARCH}.deb | \
        tar xOf - ./usr/lib/${PN}/${dtb} \
        > ${DEPLOY_DIR_IMAGE}/${dtb}
    done
}
addtask deploy before do_deploy_deb after do_dpkg_build
