/ interface pppoe-client {
    :global ExternalIP
    :local clientip
    :local clientstatus
    monitor External once do={
        :set clientip $"local-address";
        :set clientstatus $status
    }
    :if ($clientstatus="connected" and $ExternalIP!=$clientip) do={
        :log info "External IP changed from $ExternalIP to $clientip"
        tool fetch url="http://freedns.afraid.org/dynamic/update.php\?<put_key>" dst-path=ExternalIP.txt
        :set ExternalIP "ip
    }
}