#!/usr/bin/env bashio

DEBUG=/bin/false
if [ "$(bashio::config 'debug')" == "true" ]; then
	DEBUG=/bin/true
fi


HOSTAPD_CONFIG="/etc/hostapd/hostapd.conf"
INTERFACES_CONFIG="/etc/network/interfaces"
DNSMASQ_CONFIG="/etc/dnsmasq.conf"


function flush_net () {

	ifname="$(bashio::config 'interface')"
	ifname="${1:-$ifname}"
	ip link set $ifname down
	ip addr flush dev $ifname 
	ip addr show  $ifname
	unset ifname

}


function clean_stop () {
	bashio::log.info "Clean stop" &
	flush_net
	ifdown $(bashio::config 'interface')
	ip route show
	sleep 5
}
trap 'clean_stop' SIGTERM
trap 'clean_stop' TERM


if_names="$(ls -d1  /sys/class/ieee80211/*/device/net/* | cut -d'/' -f8 | tr '\n' ' ')"
bashio::log.info "List all available wireless interfaces : $if_names"


if [ "$(bashio::config 'force_reset_other_interfaces')" == "true" ]; then
	bashio::log.info "Cleaning other interfaces if they already have $(bashio::config 'address') adress"
	for ifname in $(ip route show | grep "$(bashio::config 'address')" | cut -d' ' -f3); do
		bashio::log.warning "Cleaning $ifname, having $(bashio::config 'address') ip adress"
		flush_net $ifname
	done

fi


bashio::log.info "Starting..."

# Networking part
bashio::log.info "Configure interfaces..."

bashio::log.debug "Create ${INTERFACES_CONFIG%/*} dir"
mkdir -p ${INTERFACES_CONFIG%/*}

bashio::log.debug "Create ${INTERFACES_CONFIG}"
touch $INTERFACES_CONFIG

cat <<EOF > $INTERFACES_CONFIG
auto $(bashio::config 'interface')
iface $(bashio::config 'interface') inet static
  address $(bashio::config 'address')
  netmask $(bashio::config 'netmask')
  broadcast $(bashio::config 'broadcast')
EOF

$DEBUG && cat $INTERFACES_CONFIG

bashio::log.info "Initial state :"
ip addr show  $(bashio::config 'interface')

bashio::log.info "Reset latest interface status"
flush_net

bashio::log.info "Starting interface ...";
ifup $(bashio::config 'interface')
ip addr show  $(bashio::config 'interface')


# Hostapd part
bashio::log.info "Configure hostapd ..."
sed -i "s/__INTERFACE__/$(bashio::config 'interface')/" $HOSTAPD_CONFIG
sed -i "s/__SSID__/$(bashio::config 'ssid')/" $HOSTAPD_CONFIG
sed -i "s/__CHANNEL__/$(bashio::config 'channel')/" $HOSTAPD_CONFIG
sed -i "s/__WPA_PASSPHRASE__/$(bashio::config 'wpa_passphrase')/" $HOSTAPD_CONFIG

if [ "$(bashio::config 'masked_ssid')" == "true" ]; then
	echo "ignore_broadcast_ssid=1" >> $HOSTAPD_CONFIG
fi

$DEBUG && cat $HOSTAPD_CONFIG





bashio::log.info "Configuring dnsmasq..."
# Add interface to bind
echo "interface=$(bashio::config 'interface')" >> "${DNSMASQ_CONFIG}"

# Add default forward servers
for server in $(bashio::config 'dns'); do
    echo "server=${server}" >> "${DNSMASQ_CONFIG}"
done

# Create domain forwards
for forward in $(bashio::config 'forwards|keys'); do
    DOMAIN=$(bashio::config "forwards[${forward}].domain")
    SERVER=$(bashio::config "forwards[${forward}].server")

    echo "server=/${DOMAIN}/${SERVER}" >> "${DNSMASQ_CONFIG}"
done

# Create static hosts
for host in $(bashio::config 'hosts|keys'); do
    HOST=$(bashio::config "hosts[${host}].host")
    IP=$(bashio::config "hosts[${host}].ip")

    echo "address=/${HOST}/${IP}" >> "${DNSMASQ_CONFIG}"
done

# DHCP configuration
echo "# DHCP range" >> ${DNSMASQ_CONFIG}
echo "dhcp-range=$(bashio::config 'dhcp_range'),12h" >> ${DNSMASQ_CONFIG}
echo "# Netmask" >> ${DNSMASQ_CONFIG}
echo "dhcp-option=1,$(bashio::config 'netmask')" >> ${DNSMASQ_CONFIG}
echo "# Route" >> ${DNSMASQ_CONFIG}
echo "dhcp-option=3,$(bashio::config 'address')" >> ${DNSMASQ_CONFIG}


$DEBUG && cat $DNSMASQ_CONFIG


# Executions

bashio::log.info "Starting HostAP daemon ..." 
hostapd  -B -P /tmp/hostapd.pid /etc/hostapd/hostapd.conf 

$DEBUG && bashio::log.debug "Print Network configuration"
$DEBUG && bashio::log.debug "ip addr show $(bashio::config 'interface')"
$DEBUG && ip addr show $(bashio::config 'interface')
$DEBUG && bashio::log.debug "ip route show"
$DEBUG && ip route show

bashio::log.info "Starting dnsmasq..."
nohup dnsmasq -C "${DNSMASQ_CONFIG}" -z -x /tmp/dnsmasq.pid &

bashio::log.info "Starting monitoring of dnsmasq and hostapd process..."
while :; do
	if ! ps aux | grep -q $(cat /tmp/hostapd.pid); then
		bashio::log.error "hostapd is down !"
		flush_net 
		kill $(cat /tmp/hostapd.pid)
		exit 1
	fi

	if ! ps aux | grep -q $(cat /tmp/hostapd.pid); then
		bashio::log.error "dnsmasq is down !"
		flush_net
		kill $(cat /tmp/hostapd.pid)
		exit 2
	fi


	sleep 10
done
