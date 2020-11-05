ARG BUILD_FROM
FROM $BUILD_FROM

MAINTAINER Sébastien Boyron <sebastien@boyron.eu>

# Set shell
#SHELL ["/bin/bash", "-o", "pipefail", "-c"]


# Install requirements for add-on
RUN apk add --no-cache hostapd dnsmasq

COPY dnsmasq.conf /etc/
COPY hostapd.conf /etc/hostapd/hostapd.conf
COPY run.sh /

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
