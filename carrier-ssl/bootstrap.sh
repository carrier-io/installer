#!/bin/bash

docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user carrier --password carrier \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh update realms/master -s sslRequired=NONE \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh update realms/carrier -s sslRequired=NONE \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh create groups -r carrier -s name=superadmin \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh create groups -r carrier -s name=grafana \
&& groupid=`docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh get groups -r carrier | grep id | cut -d: -f2 | sed s/' '//g | sed s/'"'//g | sed s/','//g` \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh update users/8a9a3cec-5e13-42cd-8736-a0e97598d86e/groups/${groupid:0:36} -r carrier -s realm=carrier -s userId=8a9a3cec-5e13-42cd-8736-a0e97598d86e -s groupId=${groupid:0:36} -n \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh update users/8a9a3cec-5e13-42cd-8736-a0e97598d86e/groups/${groupid:37:72} -r carrier -s realm=carrier -s userId=8a9a3cec-5e13-42cd-8736-a0e97598d86e -s groupId=${groupid:37:72} -n \
&& docker exec carrier-keycloak /opt/jboss/keycloak/bin/kcadm.sh update realms/carrier -s "loginTheme=carrier"

docker cp /installer/grafana/datasources/. carrier-grafana:/etc/grafana/provisioning/datasources
docker cp /installer/grafana/def.yml carrier-grafana:/etc/grafana/provisioning/dashboards
docker cp /installer/grafana/dashboards/. carrier-grafana:/etc/grafana/provisioning/dashboards

sed -i "s/INFLUX_USER/INFLUXUSERNAME/g" /installer/grafana/datasources/telegraf_docker.yml
sed -i "s/INFLUX_PASSWORD/INFLUXPASSWORD/g" /installer/grafana/datasources/telegraf_docker.yml
GF_API_KEY=$(curl -H "Content-Type: application/json" --request POST --data '{"name":"admin","role":"Admin","secondsToLive":null}' $1://user:user@$2/grafana/api/auth/keys)
key=$(echo "${GF_API_KEY}" | sed 's/{"name":"admin","key":"//' | sed 's/"}//')
sed -i "s#GF_API_KEY=api_key#GF_API_KEY=$key#g" $3/carrier-ssl/.env

docker restart carrier-grafana
docker exec carrier-influx bash -c "influx -execute \"create user INFLUXUSERNAME with password 'INFLUXPASSWORD' with all privileges;\""
docker exec carrier-influx bash -c "influx -username 'INFLUXUSERNAME' -password 'INFLUXPASSWORD' -execute 'create database carrier'"