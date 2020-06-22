# Mikrotik script - Meraki VPN Interactive Menu

Scenario:
You configure your Mikrotik router to be a L2TP Client to a Meraki. You may
  have a few L2TP clients setup this way. This interactive script (only
  via **ssh** or **telnet**) will search for clients and enable or disable the
  one you select.

The script identifies clients by the comment on the L2TP interface, NAT rule
  and Routes. Therefore, the comment must be exactly the same on all three types.

The L2TP interfaces need to use a profile named **meraki** for the detection
  to work (setup below).

The script will check for an active VPN first, which must be disabled prior
  to enabling a new VPN.

## Prerequisite setup
Common Settings (this should always be enabled, firewall rule preference may
  need to be adjusted):

    # Meraki profile
    /ppp profile add name=meraki use-encryption=required use-ipv6=no \
     use-mpls=no

    # Set ipsec profile and proposal, 3des and aes128, group2 and group5
    /ip ipsec profile set [ find default=yes ] dh-group=modp1536,modp1024 \
     lifetime=8h
    /ip ipsec proposal set [ find default=yes ] \
     enc-algorithms=aes-128-cbc,3des lifetime=8h pfs-group=none

    # Mark routing for traffic from only allowed sources
    /ip firewall mangle add action=mark-routing chain=prerouting \
     comment="Leave this enabled always" new-routing-mark=merakivpns \
     passthrough=yes src-address-list="Source VPN Addresses"

    # Address List
    # Sample of two shown below. Use as many or as few as needed.
    /ip firewall address-list add address=LOCALADDRESS1 \
     list="Source VPN Addresses"
    /ip firewall address-list add address=LOCALADDRESS2 \
     list="Source VPN Addresses"


Per Client Settings (firewall rule preference may need to be adjusted):

    # L2TP Client Setup, take note of the interface name
    /interface l2tp-client add allow=pap comment=CLIENTNAME \
     connect-to=DESTINATION ipsec-secret=SECRET name=l2tp-out1 \
     password=PASSWORD profile=meraki use-ipsec=yes \
     user="DOMAIN\\user||user@domain.com||user"
    /interface l2tp-client disable name=l2tp-out1

    # Address List
    # Sample of two shown below. Use as many or as few as needed.
    /ip firewall address-list add address=DSTADDRESS1 list=CLIENTNAME
    /ip firewall address-list add address=DSTADDRESS2 list=CLIENTNAME

    # Firewall rule to NAT traffic for valid sources addresses to
    # destination routes
    /ip firewall nat add action=masquerade chain=srcnat comment=CLIENTNAME \
     disabled=yes dst-address-list=CLIENTNAME out-interface=l2tp-out1 \
     src-address-list="Source VPN Addresses"

    # Routes
    # Sample of two shown below. Use as many or as few as needed.
    /ip route add comment=CLIENTNAME disabled=yes distance=1 \
     dst-address=DSTADDRESS1 gateway=l2tp-out1 routing-mark=merakivpns
    /ip route add comment=CLIENTNAME disabled=yes distance=1 \
     dst-address=DSTADDRESS2 gateway=l2tp-out1 routing-mark=merakivpns

## Sample Runs
Enable (detected no active VPNs):

    List of Meraki L2TP Clients
      1.  Client A
      2.  Client B
      3.  Client C
      4.  Client D
      5.  Client E
      X.  Exit
    What client would you like to enable? (1-5 or eXit)
    value: 4
    Enabling L2TP Client for Client D...OK!
    Enabling NAT rule for Client D...OK!
    Enabling routes for Client D:
      - 10.0.0.0/11....OK!
      - 192.168.0.0/19....OK!
    Route changes..OK!
    All rules for Client D have been enabled!

Disable (active VPN detected, will ask if you want to enable a new VPN):

    Client D Backup is currently enabled. Would you like to disable (Y/n)?
    value: y
    Disabling L2TP Client for Client D...OK!
    Disabling NAT rule for Client D...OK!
    Disabling routes for Client D:
      - 10.0.0.0/11....OK!
      - 192.168.0.0/19....OK!
    Route changes..OK!
    All rules for Client D have been disabled!
    Do you want to enable another VPN (y/N)?
    value: n
    Goodbye!
