# Source: http://wiki.mikrotik.com/wiki/Setting_static_DNS_record_for_each_DHCP_lease
# DNS record for DHCP lease
# Prepare variables in use
:local topdomain;
:local hostname;
:local hostip;

# Configure your domain
:set topdomain "dhcp.yourdomain.com";

/ip dhcp-server lease;
:foreach i in=[find] do={
  /ip dhcp-server lease;
  :if ([:len [get $i host-name]] > 0) do={
    :set hostname ([get $i host-name] . "." . $topdomain);
    :set hostip [get $i address];
    /ip dns static;
# Remove if DNS entry already exist
    :foreach di in [find] do={
      :if ([get $di name] = $hostname) do={
        :put ("Removing: " . $hostname . " : " . $hostip);
        remove $di;
      }
    }
# Add DNS entry
    :put ("Adding: " . $hostname . " : " . $hostip);
    /ip dns static add name=$hostname address=$hostip;
  }
}
