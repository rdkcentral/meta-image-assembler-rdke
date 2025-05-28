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
        install -D -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/community-rfc-configs.ini ${IMAGE_ROOTFS}/etc/rfcdefaults/community-rfc-configs.ini
    fi
}

# Mandatory: Add rdkhell key mapping of the supported RCU. Make sure to align with Device bundled RCU.
ROOTFS_POSTPROCESS_COMMAND:append = " map_rdkshell_keys;"
map_rdkshell_keys() {
    bbnote "Installing Reference RCU(tatlow) RDKShell keymap..."
    install -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/rdkshell_keymapping.json ${IMAGE_ROOTFS}/etc/rdkshell_keymapping.json
    # Add RDKSHELL_KEYMAP_FILE if not defined in ${IMAGE_ROOTFS}/lib/systemd/system/wpeframework*
    if ! grep -q "RDKSHELL_KEYMAP_FILE" ${IMAGE_ROOTFS}/lib/systemd/system/wpeframework*; then
        bbnote "RDKSHELL_KEYMAP_FILE not defined, adding drop-in configuration..."
        install -D -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/rdkshell_keymap.conf ${IMAGE_ROOTFS}/lib/systemd/system/wpeframework.service.d/rdkshell_keymap.conf
    fi
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

# Temporary: Community RCU Control manager configuration. This needs to be removed once RDKEMW-901 is fixed.
ROOTFS_POSTPROCESS_COMMAND:append = " ctrlm_community_remote_fix;"
ctrlm_community_remote_fix() {
    if [ ! -f ${IMAGE_ROOTFS}/etc/ctrlm_config.json ]; then
        bbnote "Adding Community RCU Control manager configurations..."
        install -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/rdk-bt-rcu-config.json ${IMAGE_ROOTFS}/etc/ctrlm_config.json
    else
        bbnote "Detected default RCU Control manager configurations, skipping Community RCU Control manager configuration."
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

#Updatintg DAC Server URL back to consult red server until the new DAC Server is ready
ROOTFS_POSTPROCESS_COMMAND:append = " add_lisa_config_url;"
add_lisa_config_url() {
    LISA_JSON="${IMAGE_ROOTFS}/etc/WPEFramework/plugins/LISA.json"
    if [ -f "$LISA_JSON" ]; then
        # Add a comma at the end of dacBundleFirmwareCompatibilityKey line if missing
        sed -i '/"dacBundleFirmwareCompatibilityKey"[[:space:]]*:/s/"$/",/' "$LISA_JSON"
        # Insert configUrl after the dacBundleFirmwareCompatibilityKey line
        sed -i '/"dacBundleFirmwareCompatibilityKey"[[:space:]]*:/a\    "configUrl": "https://280222515084-rdkm-apps-resources.s3.eu-central-1.amazonaws.com/configuration/cpe.json"' "$LISA_JSON"
    else
        bbwarn "LISA.json not found, skipping configUrl injection."
    fi
}
