# Home Assistant Add-on: Access Point

Isolated wifi hotspot feature to Home Assistant.


## About

An add-on to create a wifi hotspot including the hotspot, the DHCP server and the DNS server.
This access-point is an isolated network not routed to homeassistant external network. 


## Architecture 

This add-on is based on the standard Home Assistant docker image.

All the hotspot part is managed by **hostapd**. The DNS and DHCP feature are performed by **dnsmasq**.

I chosed to use a single container to run hostapd and dnsmasq to have a single add-on performing the whole
access point feature. All configuration is so mutualised and is used to configure the system, then hostapd
and dnsmasq. This imply to have some minor monitoring on the good execution of hostapd AND dnsmasq. This is
performed by a basic shell script, checking pid are still running.


## Install

To install this add-on, you have to add my repo on your homeassistant add-ons configuration. 


To perform it you just have to add my repository (https://github.com/dj4ngo/hassio-addons)
in the **Add-on Store** page using the top right-corner button.


Since add-on is requiring a full access to the network devices you have to enable the advanced mode for
being able to install it. You directly can do it from your user profile.



## Configuration

The Configuration is perform from a standard way through the add-on configuration page.


### Configuration example 

Here is a full working example of configuration :

``` yaml
interface: wlan0
ssid: Pi
masked_ssid: true
force_reset_other_interfaces: false
wpa_passphrase: raspberry
channel: 6
address: 192.168.99.1
netmask: 255.255.255.0
broadcast: 192.168.99.254
dhcp_range: '192.168.99.100,192.168.99.150'
dns:
  - 192.168.99.1
forwards:
  - domain: test.io
    server: 10.10.10.10
  - domain: test2.io
    server: 10.10.10.11
hosts:
  - host: hostname1
    ip: 192.168.99.10
  - host: hostname2
    ip: 192.168.99.11
debug: false
```

### System configuration

#### interface: wlan0
  
You can select here your wireless device. If you plug an usb wirless device to 
Home Assistant; you can find the name in the logs at the beginning of the execution : 

```
[12:26:48] INFO: List all available wireless interfaces : wlp1s0u1u2 wlan0
```
Here we can see two wireless devices, one called wlan0 and the other one wlp1s0u1u2.

#### address: 192.168.99.1

Here is the desired IP adress of the hotspot device.

#### netmask: 255.255.255.0

Here the desired netmask of the hotspot subnet.

#### broadcast: 192.168.99.254

The broadcast IP is required here.

#### force_reset_other_interfaces: false

This setting should be used with caution. It will force the de-configuration of every
network interfaces already having ip address defined in **address** param. This can
be usefull during tests when changing from an interface to another one if the add-on
does not clean correctly the network configuration from an execution to an other one.

***Caution:* This can break the homeassistant network configuration if not used correctly
requiring a reboot of homeassistant. If you define homeassistant IP adress in address field
and enable the addon on boot, this will block you even on a reboot if home assistant keep
the same IP**


### Hotspot configuration

The hotspot configuration is based on previous parameters and these additionnal ones :

#### ssid: Pi

Set the desired SSID for this network.

#### masked_ssid: false

Setting this parameter to true will mask the SSID. The SSID will so not be visible.

#### wpa_passphrase: raspberry

Here is the password/passphrase of the network. Only WPA2 authentication method is
available.


#### channel: 6

Define the WiFi channel.


### DHCP & DNS Configuration

DHCP configuration is based on system parameters and these additional ones :

#### dhcp_range: '192.168.99.100,192.168.99.150'

Define the dhcp range.

#### dns

```yaml
dns:
  - 192.168.99.1
```

This is a list of default DNS servers.

#### forwards

```yaml
forwards:
  - domain: test.io
    server: 10.10.10.10
  - domain: test2.io
    server: 10.10.10.11
```

Forwards parameter list allow forwarding dns queries to an other DNS server
for some specific domains.

This can be used to fake dns to avoid some devices accessing to the net for 
example.

#### hosts
 
```yaml
hosts:
  - host: hostname1
    ip: 192.168.99.10
  - host: hostname2
    ip: 192.168.99.11
debug: false
```

Hosts parameter is a list of DNS resolution to assing a DNS to an IP address.


### Generated configurations

Here are all the generated configuration from the example :

#### System config :

file: etc/network/interfaces
```
auto wlp1s0u1u2
iface wlp1s0u1u2 inet static
  address 192.168.99.1
  netmask 255.255.255.0
  broadcast 192.168.99.254
```

#### Hostapd configuration :

file: /etc/hostapd/hostapd.conf :
```
interface=wlp1s0u1u2
driver=nl80211
# Use the 2.4GHz band
hw_mode=g
# Accept all MAC addresses
macaddr_acl=0
# Bit field: 1=wpa, 2=wep, 3=both
auth_algs=1
ssid=Pi
channel=6
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_pairwise=CCMP
wpa_passphrase=raspberry
ignore_broadcast_ssid=1
```

#### Dnsmasq configuration :

file: /etc/dnsmasq.conf
```
no-resolv
no-hosts
log-queries
log-facility=-
no-poll
user=root
interface=wlp1s0u1u2
server=192.168.99.1
server=/test.io/10.10.10.10
server=/test2.io/10.10.10.11
address=/hostname1/192.168.99.10
address=/hostname2/192.168.99.11
# DHCP range
dhcp-range=192.168.99.100,192.168.99.150,12h
# Netmask
dhcp-option=1,255.255.255.0
# Route
dhcp-option=3,192.168.99.1
```




