SUMMARY = "RDK Full Stack image"

LICENSE = "MIT"

DEPENDS += "nss-native"

IMAGE_INSTALL = " \
                 packagegroup-vendor-layer \
                 packagegroup-middleware-layer \
                 packagegroup-application-layer \
                 "
# VOLATILE_BINDS configuration can change for each layer, it has to be built locally across all layer
IMAGE_INSTALL:append = " volatile-binds"

inherit core-image custom-rootfs-creation extrausers

EXTRA_USERS_PARAMS:append = "${@bb.utils.contains('DISTRO_FEATURES', 'amazon_non_root_support', '''\
    groupadd -g 1000 amazon;\
    useradd -u 1000 -g amazon -M -r -s /bin/sh amazon;\
''', '', d)}"

IMAGE_ROOTFS_SIZE ?= "8192"
IMAGE_ROOTFS_EXTRA_SPACE:append = "${@bb.utils.contains("DISTRO_FEATURES", "systemd", " + 4096", "" ,d)}"

create_init_link() {
        ln -sf /sbin/init ${IMAGE_ROOTFS}/init
}

ROOTFS_POSTPROCESS_COMMAND:append = " create_init_link;"

