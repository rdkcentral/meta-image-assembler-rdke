SUMMARY = "RDK Full Stack image"

LICENSE = "MIT"

DEPENDS += "nss-native"

IMAGE_INSTALL = " \
                 packagegroup-vendor-layer \
                 packagegroup-middleware-layer \
                 "

inherit core-image custom-rootfs-creation extrausers

IMAGE_ROOTFS_SIZE ?= "8192"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "" ,d)}"

create_init_link() {
        ln -sf /sbin/init ${IMAGE_ROOTFS}/init
}

ROOTFS_POSTPROCESS_COMMAND:append = " create_init_link;"

