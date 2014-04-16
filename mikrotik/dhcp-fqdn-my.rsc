# Installation:
# 1. Modify settings
# 2. Cut&paste contents of this file to console
#    or:
# 2. Save modified file, upload via tftp, sftp, web, etc.
# 3. Run /import dhcp-fqdn-my.rsc

:global chopzero do={
    :local string $1
    :local end [:find $string "\00"]
    :if ($end > 0) do={
        :return [:pick $string 0 $end]
    }
    :return $string
}

:global dnssethost do={
    :global chopzero
    :local hostname [$chopzero $1]
    :local ip $2
    :local leasetime [/ip dhcp-server get [find name=default] lease-time]
    :put $hostname
    /ip dns static
    :local items ([find address=$ip], [find name=$hostname address!=$ip])
    :if ([:len $items] > 0) do={
        set ($items->0) name=$hostname address=$ip ttl=$leasetime
        :set items [:pick $items 1 99999999]
        :if ([:len $items] > 0) do={
            remove $items
        }
    } else={
        add name=$hostname address=$ip ttl=$leasetime
    }
}

/system script
remove [find name="dhcp-on-lease"]
add name="dhcp-on-lease" source={
    :if ($leaseBound = 1) do={
        /ip dhcp-server lease
        :local hostname [get [find active-address=$leaseActIP] host-name]
        $dnssethost $hostname $leaseActIP
    } else={
        /ip dns static
        remove [find address=$leaseActIP]
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

        :if ($hostname != "") do={
            $dnssethost $hostname $ip
        }
    }
}
/system script run dhcp-names-refresh
/ip dns static print

/ip dhcp-server
set [find name="default"] lease-script=dhcp-on-lease
