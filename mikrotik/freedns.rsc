# Installation:
# 1. Modify settings
# 2a. Cut&paste contents of this file to console
# 2b. Or save modified file, upload via tftp, sftp, web, etc.
# 3b. Run /import freedns.rsc

:global freednsCheckInterval 10m

/system scheduler
remove [find name="freednsCheck"]
remove [find name="freednsUpdate"]

/system script

remove [find name="freednsCheck"]
add name="freednsCheck" source={
#   Required. Can be set to 'auto' if there is only one default gateway.
    :global freednsGateIface "auto"

#   Required. Set it to FreeDNS key string (query string after ? char).
    :global freednsKey "!!!SET TO VALID KEY!!!"

#   Optional. Fill it with FQDN or leave it blank to skip verify&retry.
    :global freednsVerify ""

#   In case freednsVerify is not empty, all freednsRetry* settings are required!
    :global freednsRetryInterval 5m

#   Stop trying after this count of failures. 0 means 'infinity'
    :global freednsRetryMax 100

#   Log warning after this count of failures. 0 means 'never'
    :global freednsRetryWarn 10


    /ip route
    :if ($freednsGateIface="auto") do={
        :set freednsGateIface [get [ \
            find dst-address=0.0.0.0/0 ] \
            value-name="vrf-interface"]
        :log debug "freednsCheck: gateway interface IP: $freednsGateIface"
    }

    :local gateRemoteIp
    :set gateRemoteIp [get [ \
            find dst-address=0.0.0.0/0 and vrf-interface=$freednsGateIface] \
        value-name=gateway]
    :log debug "freednsCheck: gateway remote IP: $gateRemoteIp"

    :local gateLocalIp
    :set gateLocalIp [get [ \
            find gateway=$freednsGateIface] \
        value-name=pref-src]
    :log debug "freednsCheck: gateway local IP: $gateLocalIp"

    /interface ethernet
    :local linkStatus
    monitor [find name=$freednsGateIface] once do={
        :set linkStatus $status
    }
    :log debug "freednsCheck: link status: $linkStatus"

    :global freednsIp
    :if ($linkStatus = "link-ok" and $freednsIp != $gateLocalIp) do={
        :log info "freednsCheck: IP changed on $freednsGateIface from $freednsIp to $gateLocalIp"
        :set freednsIp $gateLocalIp
        :if ([:len $freednsVerify] > 0) do={
            :log debug "freednsCheck: scheduling freednsUpdate at $freednsRetryInterval"
            /system scheduler
            remove [find name="freednsUpdate"]
            add name="freednsUpdate" interval=$freednsRetryInterval on-event="freednsUpdate"
        }
        :log debug "freednsCheck: running freednsUpdate now"
        /system script run freednsUpdate
    } else={
        :log debug "freednsCheck: no update required or link is not ok"
    }
}

remove [find name="freednsUpdate"]
add name="freednsUpdate" source={
    :global freednsGateIface
    :global freednsIp
    :global freednsKey
    :global freednsVerify
    :global freednsRetryInterval
    :global freednsRetryMax
    :global freednsRetryWarn

    /interface ethernet
    :local linkStatus
    monitor [find name=$freednsGateIface] once do={
        :set linkStatus $status
    }
    :log debug "freednsUpdate: link status: $linkStatus"

    :if ($linkStatus = "link-ok") do={
        :local resolvedIp
        :if ([:len $freednsVerify] > 0) do={
            /system scheduler
            :local runCount [get [find name="freednsUpdate"] value-name="run-count"]
            :log debug "freednsUpdate: retry count: $runCount"
            :if ($runCount > 0 and $runCount = $freednsRetryWarn) do={
                :log warning "freednsUpdate: failed to update $freednsVerify to $freednsIp"
            }
            :if ($freednsRetryMax > 0 and $runCount > $freednsRetryMax) do={
                :log debug "freednsUpdate: freednsRetryMax($freednsRetryMax) retry count has reached, stopping"
                /system scheduler remove [find name="freednsUpdate"]
                :return 0
            } else={
                :do {
                    :set resolvedIp [:resolve $freednsVerify]
                } on-error={ :nothing }
                :log debug "freednsUpdate: resolved $freednsVerify to $resolvedIp"
            }
        }
        :if ($resolvedIp = $freednsIp) do={
            :log debug "freednsUpdate: successfully updated to $freednsIp, stopping scheduler"
            /system scheduler remove [find name="freednsUpdate"]
        } else={
            :log debug "freednsUpdate: sending request to freedns.afraid.org"
            /tool fetch \
                mode=http \
                address="freedns.afraid.org" \
                host="freedns.afraid.org" \
                src-path="dynamic/update.php\?$freednsKey" \
                keep-result=no
        }
    }
}

/system scheduler add name="freednsCheck" interval=$freednsCheckInterval on-event="freednsCheck"

environment remove [find name="freednsIp"]
environment remove [find name="freednsCheckInterval"]

run freednsCheck
/log print
