FROM ubuntu:14.04
RUN apt-get update && \
    apt-get install -y wget && \
    wget -O /etc/apt/sources.list.d/scylla.list http://downloads.scylladb.com/deb/ubuntu/scylla.list && \
    apt-get update && \
    apt-get install -y scylla-server scylla-jmx scylla-tools --force-yes

RUN chown -R scylla:scylla /etc/scylla
RUN chown -R scylla:scylla /etc/scylla.d

# USER scylla
EXPOSE 10000 9042 9160 7000 7001
VOLUME /var/lib/scylla

ADD ./k8s-entrypoint.sh /k8s-entrypoint.sh
ADD ./ready-probe.sh /ready-probe.sh
RUN chmod +x /ready-probe.sh
ENTRYPOINT ["/k8s-entrypoint.sh"]
CMD []
