# Meraki VPN Interactive Menu
# Enable a L2TP client configured to connect to a Meraki from a Mikrotik Router
# Version 0.1.0
# Author: Dennis Cole III
# License: MIT
#
# Prerequisites:
# (Common Settings)
# /ppp profile add name=meraki use-encryption=required use-ipv6=no use-mpls=no
# /ip ipsec profile set [ find default=yes ] dh-group=modp1536,modp1024 \
# lifetime=8h
# /ip ipsec proposal set [ find default=yes ] enc-algorithms=aes-128-cbc,3des \
# lifetime=8h pfs-group=none
# /ip firewall mangle add action=mark-routing chain=prerouting comment=\
# "Leave this enabled always" new-routing-mark=merakivpns passthrough=yes \
# src-address-list="Allowed To VPN"
#
# (Each client should have the following)
# /interface l2tp-client add allow=pap comment=CLIENTNAME connect-to=\
# DESTINATION ipsec-secret=SECRET name=l2tp-out1 password=PASSWORD profile=\
# meraki use-ipsec=yes user="DOMAIN\\user||user@domain.com||user"
# /interface l2tp-client disable name=l2tp-out1
##
## Sample of two shown below. Use as many or as few as needed.
# /ip firewall address-list add address=LOCALADDRESS1 list=\
# "Source VPN Addresses"
# /ip firewall address-list add address=LOCALADDRESS2 list=\
# "Source VPN Addresses"
## End of Sample
## Sample of two shown below. Use as many or as few as needed.
# /ip firewall address-list add address=DSTADDRESS1 list=CLIENTNAME
# /ip firewall address-list add address=DSTADDRESS2 list=CLIENTNAME
## End of Sample
# /ip firewall nat add action=masquerade chain=srcnat comment=CLIENTNAME \
# disabled=yes dst-address-list=CLIENTNAME out-interface=l2tp-out1 \
# src-address-list="Source VPN Addresses"
## Sample of two shown below. Use as many or as few as needed.
# /ip route add comment=CLIENTNAME disabled=yes distance=1 dst-address=\
# DSTADDRESS1 gateway=l2tp-out1 routing-mark=merakivpns
# /ip route add comment=CLIENTNAME disabled=yes distance=1 dst-address=\
# DSTADDRESS2 gateway=l2tp-out1 routing-mark=merakivpns
## End of Sample

# Function to get input
:global read do={:return}

# Funtion to enable or disable L2TP Client
:global changeClient do={
  # Getting our NAT rules and routes
  :local natRule [/ip firewall nat find where comment=$clientName]
  :local routes [/ip route find where comment=$clientName]

  # Boolean variables
  :local l2tpInterfaceChangeStatus true
  :local natRuleChangeStatus true
  :local oneRouteChangeStatus
  :local partialRouteChanges
  :local allRoutesChangeStatus true

  # Message and other variables
  :local done "..OK!"
  :local halfDone "..some failed!"
  :local failed "..FAILED!"
  :local lowerPrefix
  :local upperPrefix
  # Delay between command execution
  :local delayTime 500ms

  if ($change="enable") do={
    :set lowerPrefix "en"
    :set upperPrefix "En"
  } else={
    :set lowerPrefix "dis"
    :set upperPrefix "Dis"
  }

  # L2TP Client Enable/Disable
  if ($change="enable") do={
    do {
      /interface l2tp-client enable [find comment=$clientName]
    } on-error={
      :set $l2tpInterfaceChangeStatus false
    }
  } else={
    do {
      /interface l2tp-client disable [find comment=$clientName]
    } on-error={
      :set $l2tpInterfaceChangeStatus false
    }
  }
  delay $delayTime
  if ($l2tpInterfaceChangeStatus) do={
    :put ($upperPrefix . "abling L2TP Client for $clientName." . $done)
  } else={
    :put ($upperPrefix . "abling L2TP Client for $clientName." . $failed)
  }

  # NAT Rule Change
  if ($change="enable") do={
    do {
      /ip firewall nat enable [find comment=$clientName]
    } on-error={
      :set $natRuleChangeStatus false
    }
  } else={
    do {
      /ip firewall nat disable [find comment=$clientName]
    } on-error={
      :set $natRuleChangeStatus false
    }
  }
  delay $delayTime
  if ($natRuleChangeStatus) do={
    :put ($upperPrefix . "abling NAT rule for $clientName." . $done)
  } else={
    :put ($upperPrefix . "abling NAT rule for $clientName." . $failed)
  }

  # Route Changes
  delay $delayTime
  :put ($upperPrefix . "abling routes for $clientName:")
  delay $delayTime
  foreach route in $routes do={
    :set $oneRouteChangeStatus true
    :local dstAddress [/ip route get value-name=dst-address \
      [find where .id=$route]]
    if ($change="enable") do={
      do {
        /ip route enable [find .id=$route]
      } on-error={
        :set $oneRouteChangeStatus false
      }
    } else={
      do {
        /ip route disable [find .id=$route]
      } on-error={
        :set $oneRouteChangeStatus false
      }
    }
    delay $delayTime
    :set $allRoutesChangeStatus ($oneRouteChangeStatus && \
      $allRoutesChangeStatus)
    if ($oneRouteChangeStatus) do={
      :set $partialRouteChanges true
      :put "  - $dstAddress.$done"
    } else={
      :put "  - $dstAddress.$done"
    }
  }
  if ($allRoutesChangeStatus) do={:put ("Route changes" . $done)} else={
    if ($partialRouteChanges) do={:put ("Route changes" . $halfDone)} else={
      :put ("Routes changes" . $failed)
    }
  }
  if ($l2tpInterfaceChangeStatus && $natRuleChangeStatus && \
    $allRoutesChangeStatus) do={
    :put ("All rules for $clientName have been $lowerPrefix" . "abled!")
  } else={
    if ($l2tpInterfaceChangeStatus || $natRuleChangeStatus || \
      $allRoutesChangeStatus) do={
      :put ("Some rules were not $lowerPrefix" . "abled.")
    } else={
        :put "All rule changes failed."
    }
  }
}

# Main routine

# Boolean variables
:local skipEnable false

# Message variables
:local goodbye "Goodbye!"

# Check for Active L2TP Clients
:local merakiL2tpActive [/interface l2tp-client find where profile="meraki" \
  disabled=no]

# If there are Active L2TP Clients, we want to disable first.
foreach merakiClient in=$merakiL2tpActive do={
  # Getting Info on the Active Client
  :local clientName [/interface l2tp-client get \
    [find where .id=$merakiClient] value-name=comment]

  # Ask to disable Active Client
  :put "$clientName is currently enabled. Would you like to disable (Y/n)?"
  :local userinput [$read]
  if ( $userinput = "n" || $userinput = "N") do={
    # We don't want to disable so we will end the script
    :set $skipEnable true
    :put $goodbye
  } else={
    # We will disable all rules
    $changeClient clientName=$clientName change="disable"
  }

  # Do we want to enable another client?
  :put "Do you want to enable another VPN (y/N)?"
  :local userinput [$read]
  if (!( $userinput = "y" || $userinput = "Y")) do={
   :set $skipEnable true
   :put $goodbye
  }
}

# Now asking what VPN do we want to enable, that is, if we are not skipping
if (!$skipEnable) do={
  :local merakiL2tpInactive [/interface l2tp-client find where \
    profile="meraki" disabled=yes]
  :local merakiClientsbyName [ :toarray "" ]

  # Get all Meraki L2TP Clients
  foreach merakiClient in=$merakiL2tpInactive do={
    :local clientName [/interface l2tp-client get \
      [find where .id=$merakiClient] value-name=comment]
    :set merakiClientsbyName ( $merakiClientsbyName, $clientName )
  }
  # List Clients
  :local i 1
  :local numOfClients [ :len $merakiClientsbyName ]
  :put "List of Meraki L2TP Clients"
  foreach clientName in $merakiClientsbyName do={
    :put "  $i.   $clientName"
    :set i ($i+1)
  }
  :put "  X.   Exit"

  # Decide which client to enable
  :put "What client would you like to enable? (1-$numOfClients or eXit)"
  :local userinput [$read]
  if ([:typeof $userinput] = "num") do={
    # Choice needs to be 1 less
    :local choice ($userinput-1)
    if ($choice >= 0 && $choice < [:len $merakiClientsbyName]) do={
      $changeClient clientName=($merakiClientsbyName->$choice) change="enable"
    } else={
      :put $goodbye
    }
  } else={
    :put $goodbye
  }
}
