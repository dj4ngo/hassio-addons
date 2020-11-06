ARG BUILD_FROM
FROM $BUILD_FROM

MAINTAINER Sébastien Boyron <sebastien@boyron.eu>

STOPSIGNAL SIGTERM

RUN apk add --no-cache hostapd dnsmasq wireless-tools wpa_supplicant linux-firmware-brcm raspberrypi-libs

COPY run.sh /

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
