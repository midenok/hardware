# Installation:
# 1. Modify settings (global variables in the beginning of dhcp-startup)
# 2. Cut&paste contents of this file to console
#    or:
# 2. Save modified file, upload via tftp, sftp, web, etc.
# 3. Run /import dhcp-fqdn-my.rsc

/system script
remove [find name="dhcp-startup"]

add name="dhcp-startup" source={
    :global dnsLocalSuffix ".lan"

    # Chop \00 from string
    :global chopzero do={
        :local string $1
        :local end [:find $string "\00"]
        :if ($end > 0) do={
            :return [:pick $string 0 $end]
        }
        :return $string
    }

    # Update static DNS single entry for ($1=hostname, $2=IP)
    :global dnssethost do={
        :global chopzero
        :global dnsLocalSuffix
        :local hostname [$chopzero $1]
        :if ([:len $hostname] > 0) do={
            :set hostname ($hostname. $dnsLocalSuffix)
            :local ip $2
			/ip dhcp-server
			:local dhcpserv [find disabled=no invalid=no]
			:if ([:len $dhcpserv] = 0) do={
				:error "Cannot find working DHCP server (check /ip dhcp-server print where disabled=no invalid=no)"
			}
            :local leasetime [get ($dhcpserv->0) lease-time]
            /ip dns static
            :local items ([find address=$ip], [find name=$hostname address!=$ip])
            :if ([:len $items] > 0) do={
                set ($items->0) name=$hostname address=$ip ttl=$leasetime
                :log debug "DNS updated: name=$hostname address=$ip ttl=$leasetime"
                :set items [:pick $items 1 99999999]
                :if ([:len $items] > 0) do={
                    remove $items
                }
            } else={
                :log debug "DNS added: name=$hostname address=$ip ttl=$leasetime"
                add name=$hostname address=$ip ttl=$leasetime
            }
        }
    }

    /interface wireless
    :local ssid [get 0 ssid]
    :local iface [get 0 name]
    /ip address
    :local localip [get [:pick [find interface=$iface disabled=no] 0] address]
    :set localip [:pick $localip 0 [:find $localip "/"]]
    :local name [$chopzero [/system identity get name]]
    :put "Updating entry for this router: $localip $name"
    $dnssethost $name $localip
    :put "Updating other entries:"
    /system script run dhcp-names-refresh
}

/system script
remove [find name="dhcp-on-lease"]
add name="dhcp-on-lease" source={
    :global dnssethost
    :if ([:typeof $leaseBound] != "nothing") do={
        :if ($leaseBound = 1) do={
            /ip dhcp-server lease
            :local hostname [get [find active-address=$leaseActIP] host-name]
            :log info "DHCP $leaseServerName: adding $leaseActIP as $hostname"
            $dnssethost $hostname $leaseActIP
        } else={
            /ip dns static
            :log info "DHCP $leaseServerName: removing $leaseActIP"
            remove [find address=$leaseActIP]
        }
    }
}

/system script
remove [find name="dhcp-names-refresh"]
add name="dhcp-names-refresh" source={
    :global dnssethost
    /ip dhcp-server lease
    :foreach i in=[find] do={
        :local hostname [get $i host-name]
        :local ip [get $i address]

        :if ([:len $hostname] > 0) do={
            :put "$ip $hostname"
            $dnssethost $hostname $ip
        }
    }
}

/system scheduler
    remove [find name="dhcp-startup"]
    add name="dhcp-startup" start-time=startup interval=0 on-event="/system script run dhcp-startup"

/system script run dhcp-startup

/ip dhcp-server
    set [find name="default"] lease-script=dhcp-on-lease

/ip dns static print
