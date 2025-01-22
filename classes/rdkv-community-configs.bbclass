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

# Mandatory: WebPA endpoint needs to be configured in 'partners_defaults.json' by the Operator.
ROOTFS_POSTPROCESS_COMMAND:append = " update_community_webpa_url;"
update_community_webpa_url() {
    bbnote "Updating WebPA URL in partners_defaults.json..."
    python3 << EOF
import json

file_path = "${IMAGE_ROOTFS}/etc/partners_defaults.json"

with open(file_path, 'r') as file:
    data = json.load(file)

data['community']['Device.X_RDK_WebPA_Server.URL'] = "https://rdkcentral.com/webpa"

with open(file_path, 'w') as file:
    json.dump(data, file, indent=4)
EOF
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
    install -m 0644 ${MANIFEST_PATH_RDK_IMAGES}/conf/uei-tatlow-rdkshell-keymapping.json ${IMAGE_ROOTFS}/etc/rdkshell_keymapping.json
}

# Optional: To expose access of Thunder to the local network for Tests/Tools.
ROOTFS_POSTPROCESS_COMMAND:append = " wpeframework_binding_patch;"
wpeframework_binding_patch() {
    bbnote "Changing Thunder 'binding' to '0.0.0.0'..."
    sed -i "s/127.0.0.1/0.0.0.0/g" ${IMAGE_ROOTFS}/etc/WPEFramework/config.json
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
