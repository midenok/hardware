# Based on: http://wiki.mikrotik.com/wiki/Bruteforce_login_prevention
#
# Installation:
# 1. Modify settings
# 2a. Cut&paste contents of this file to console
# 2b. Or save modified file, upload via tftp, sftp, web, etc.
# 3b. Run /import ssh.rsc

{
    :local attemptTimeout 1m
    :local blacklistTimeout 10d
    :local guardInterface ether1-gateway
    :local insertBefore 3
    :local sshPort 22022

    /ip firewall filter

    :foreach rule in=[find chain=input and jump-target=ssh] do={
        remove $rule
    }

    :foreach rule in=[find chain=ssh or chain=ssh_check] do={
        remove $rule
    }

    add chain=ssh_check comment="ssh_check chain: limit connection attempts" \
        src-address-list=ssh_stage3 \
        action=add-src-to-address-list \
        address-list=ssh_blacklist \
        address-list-timeout=$blacklistTimeout

    add chain=ssh_check \
        src-address-list=ssh_stage2 \
        action=add-src-to-address-list \
        address-list=ssh_stage3 \
        address-list-timeout=$attemptTimeout

    add chain=ssh_check \
        src-address-list=ssh_stage1 \
        action=add-src-to-address-list \
        address-list=ssh_stage2 \
        address-list-timeout=$attemptTimeout

    add chain=ssh_check connection-state=new \
        action=add-src-to-address-list \
        address-list=ssh_stage1 \
        address-list-timeout=$attemptTimeout

    add chain=ssh comment="ssh chain: allow whitelisted, drop blacklisted, check attempts" \
        src-address-list=ssh_whitelist \
        action=accept

    add chain=ssh \
        src-address-list=ssh_blacklist \
        action=drop

    add chain=ssh connection-state=new \
        action=jump \
        jump-target=ssh_check

    add chain=ssh action=accept

    add chain=input protocol=tcp dst-port=$sshPort \
        action=jump \
        jump-target=ssh \
        in-interface=$guardInterface \
        place-before=$insertBefore
}
