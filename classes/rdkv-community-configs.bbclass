# rdkv-community-configs.bbclass
# Purpose: To add generic community-specific runtime configurations so that the generated
# RDKV image closely resembles an operator on-boarded device/stack.
# The following sections specify requirements and their types.

# Mandatory: Dobby configuration is device-specific. Conditionally install the required configuration if not present.
ROOTFS_POSTPROCESS_COMMAND:append = " dobby_generic_config_patch;"
dobby_generic_config_patch() {
    if [ -f "${IMAGE_ROOTFS}/etc/dobby.generic.json" ]; then
        if [ -f "${IMAGE_ROOTFS}/etc/dobby.json" ]; then
            bbnote "Removing dobby.generic.json as dobby.json exists."
            rm ${IMAGE_ROOTFS}/etc/dobby.generic.json
        else
            bbnote "Renaming dobby.generic.json to dobby.json."
            mv ${IMAGE_ROOTFS}/etc/dobby.generic.json ${IMAGE_ROOTFS}/etc/dobby.json
        fi
    fi
}

# Mandatory: Some of the RFC configurations for healthy runtime.
ROOTFS_POSTPROCESS_COMMAND:append = " install_community_rfc_configs;"
install_community_rfc_configs() {
    if [ -f "${MANIFEST_PATH_RDK_IMAGES}/conf/community-rfc-configs.ini" ]; then
        bbnote "Installing community RFC configs..."
        cfg_file="${IMAGE_ROOTFS}/etc/rfcdefaults/community-rfc-configs.ini"
        install -D -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/community-rfc-configs.ini "${cfg_file}"
        if [ -n "${DAC_APPSTORE_URL}" ]; then
            printf '\n%s\n' "Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.DAC.ConfigURL=${DAC_APPSTORE_URL}" >> "${cfg_file}"
        else
            bbwarn "DAC_APPSTORE_URL is not set. Skipping DAC configuration."
        fi
    fi
}

# Mandatory: Add windowmanager key mapping of the supported RCU.
ROOTFS_POSTPROCESS_COMMAND:append = " install_keymap;"
install_keymap() {
    if [ -z "${WINDOWMANAGER_RCU_KEYMAP_FILE}" ]; then
        bbfatal "WINDOWMANAGER_RCU_KEYMAP_FILE is not set. Cannot install keymap."
    fi
    bbnote "Installing Reference RCU keymap for Windowmanager as ${WINDOWMANAGER_RCU_KEYMAP_FILE}"
    install -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/rdkshell_keymapping.json ${IMAGE_ROOTFS}/${WINDOWMANAGER_RCU_KEYMAP_FILE}
}

# Optional: To expose access of Thunder to the local network for Tests/Tools.
ROOTFS_POSTPROCESS_COMMAND:append = " wpeframework_binding_patch;"
wpeframework_binding_patch() {
    bbnote "Checking if ${IMAGE_ROOTFS}/etc/WPEFramework/config.json exists..."
    if [ -f "${IMAGE_ROOTFS}/etc/WPEFramework/config.json" ]; then
        sed -i "s/127.0.0.1/0.0.0.0/g" ${IMAGE_ROOTFS}/etc/WPEFramework/config.json

        if grep -q "0.0.0.0" "${IMAGE_ROOTFS}/etc/WPEFramework/config.json"; then
            bbnote "Thunder 'binding' successfully updated to '0.0.0.0'."
        else
            bbwarn "Thunder 'binding' update failed. Check the sed command or config file content."
        fi
    else
        bbnote "${IMAGE_ROOTFS}/etc/WPEFramework/config.json not found. Skipping Thunder 'binding' patch."
    fi
}

# Optional: SSH keys are installed by the Operator to ensure the device is accessible securely if required.
ROOTFS_POSTPROCESS_COMMAND:append = " update_dropbearkey_path;"
update_dropbearkey_path() {
    if [ -f "${IMAGE_ROOTFS}/lib/systemd/system/dropbearkey.service" ]; then
        bbnote "Changing dropbearkey path to /opt considering ReadOnly rootfs."
        sed -i 's/\/etc\/dropbear/\/opt\/dropbear/g' ${IMAGE_ROOTFS}/lib/systemd/system/dropbearkey.service
    fi
}

# Enable Miracast ports based on distro
ROOTFS_POSTPROCESS_COMMAND:append = "${@bb.utils.contains('DISTRO_FEATURES', 'ENABLE_MIRACAST', ' update_ports_in_iptables; ', '', d)}"
update_ports_in_iptables() {
    if [ -f "${IMAGE_ROOTFS}/lib/rdk/iptables_init" ]; then
        sed -i "/${IPV4_BIN} -N SSHDROPLOG/i \\
    # MiracastService plugin need to communicate with client through below ports\\
    # 7236 - RTSP session communication\\
    # 1990 - UDP streaming for Mirroring\\
    # 67 - DHCP server to provide ip to clients through P2P group interface\\
    \$IPV4_BIN -A INPUT -p tcp -s 192.168.0.0/16 --dport 7236 -j ACCEPT\\
    \$IPV4_BIN -A INPUT -p udp -s 192.168.0.0/16 --dport 1990 -j ACCEPT\\
    \$IPV4_BIN -A INPUT -i p2p+ -p udp --dport 67 -j ACCEPT\\ \\n" "${IMAGE_ROOTFS}/lib/rdk/iptables_init"
    else
        bbnote "iptables_init file not found. Skipping Miracast iptables rules."
    fi
}
