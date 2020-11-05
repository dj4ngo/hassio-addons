#!/usr/bin/env bashio
set -x

HOSTAPD_CONFIG="/etc/hostapd/hostapd.conf"
INTERFACES_CONFIG="/etc/network/interfaces"
DNSMASQ_CONFIG="/etc/dnsmasq.conf"


# SIGTERM-handler this funciton will be executed when the container receives the SIGTERM signal (when stopping)
term_handler(){
	bashio::log.info "Stop..."
	ifdown $(bashio::config 'interface')
	ip link set $(bashio::config 'interface') down
	ip addr flush dev $(bashio::config 'interface') 
	jobs=$(jobs -p)
	if [ "$jobs" != "" ]; then
		bashio::log.info "Kill all running jobs ($(jobs -p))"
		kill $jobs
	fi
	echo "$? $LINENO"
	exit 0
}

if_names="$(ls -d1  /sys/class/ieee80211/*/device/net/* | cut -d'/' -f8 | tr '\n' ' ')"
bashio::log.info "List all available wireless interfaces : $if_names"

# Setup signal handlers
trap 'term_handler' SIGTERM
trap 'term_handler' ERR



bashio::log.info "Starting..."

bashio::log.info "Configure hostapd ..."
sed -i "s/__INTERFACE__/$(bashio::config 'interface')/" $HOSTAPD_CONFIG
sed -i "s/__SSID__/$(bashio::config 'ssid')/" $HOSTAPD_CONFIG
sed -i "s/__CHANNEL__/$(bashio::config 'channel')/" $HOSTAPD_CONFIG
sed -i "s/__WPA_PASSPHRASE__/$(bashio::config 'wpa_passphrase')/" $HOSTAPD_CONFIG

echo "###################"
cat $HOSTAPD_CONFIG
echo "###################"


bashio::log.info "Configure interfaces..."
sed -i "s/__INTERFACE__/$(bashio::config 'interface')/" $INTERFACES_CONFIG
sed -i "s/__ADDRESS__/$(bashio::config 'address')/" $INTERFACES_CONFIG
sed -i "s/__NETMASK__/$(bashio::config 'netmask')/" $INTERFACES_CONFIG
sed -i "s/__BROADCAST__/$(bashio::config 'broadcast')/" $INTERFACES_CONFIG

echo "###################"
cat $INTERFACES_CONFIG
echo "###################"

if ifdown $(bashio::config 'interface'); then 
	echo "Interface stopped !"
fi
bashio::log.info "Starting interface ...";
ifup $(bashio::config 'interface')


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


echo "###################"
cat $DNSMASQ_CONFIG
echo "###################"



(\
 bashio::log.info "Starting HostAP daemon ..."; \
 hostapd  /etc/hostapd/hostapd.conf | sed 's/^/hostapd: /'; \
 echo "hostapd crashed !";\
 kill $$ \
)&


ip addr show $(bashio::config 'interface')

(\
 bashio::log.info "Starting dnsmasq...";\
 exec dnsmasq -C "${DNSMASQ_CONFIG}" -z < /dev/null | sed 's/^/dnsmasq: /';\
 echo "dnsmasq crashed !";\
 kill $$\
)&


wait


