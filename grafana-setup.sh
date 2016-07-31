#!/bin/bash


#modify iptables
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 81 -j ACCEPT
#iptables -I INPUT -p tcp --dport 2003 -j ACCEPT if web graphite or other if wsgi
service iptables save

#install need packeges
yum install -y python-devel mod_wsgi pycairo dejavu-sans-fonts gcc git pytz python-memcached nc 
pip install pyparsing
pip install 'Twisted<12.0'

cd /tmp
#########################################
#download web graphite, whisper, carbon
########################################
git clone https://github.com/graphite-project/graphite-web.git
git clone https://github.com/graphite-project/carbon.git
git clone https://github.com/graphite-project/whisper.git
#####################################
#install whisper, carbon, graphite-web
#######################################

cd whisper; git checkout 0.9.13-pre1; python setup.py install
cd ../carbon; git checkout 0.9.13-pre1; python setup.py install
cd ../graphite-web; python check-dependencies.py; git checkout 0.9.13-pre1; python setup.py install
#########################################################
#install graphite-api via pip (remove # char)
############################################
#pip install graphite-api
#cat > /etc/graphite-api.yaml << "EOF"
#search_index: /srv/graphite/index
#finders:
 # - graphite_api.finders.whisper.WhisperFinder
#functions:
 # - graphite_api.functions.SeriesFunctions
 # - graphite_api.functions.PieFunctions
#whisper:
 # directories:
 #   - /srv/graphite/whisper
#time_zone: Europe/London
#EOF

###################
#or dowload GO-carbon
###############
#https://github.com/lomik/go-carbon

#######################
#install diamond via pip
#########################
pip install diamond
#################
#or download source DIAMOND
#############################
cd /tmp
git clone https://github.com/python-diamond/Diamond
cd Diamond/
python setup.py install


#####copy cinfigure file
cd /opt/graphite/conf
cp carbon.conf.example carbon.conf
cp graphite.wsgi.example graphite.wsgi
cp storage-schemas.conf.example storage-schemas.conf
cp storage-aggregation.conf.example storage-aggregation.conf

cat > /etc/nginx/conf.d/graphite.conf << "EOF"
server { 
 
	listen 81; 
	charset utf-8; 
 
	access_log /var/log/nginx/graphite.access.log; 
	error_log /var/log/nginx/graphite.error.log; 
 
	location / { 
		include uwsgi_params; 
		uwsgi_pass 127.0.0.1:3035; 
	} 
}
EOF

#config for graphite-api
#mkdir /etc/uwsgi.d/
#cat >//etc/uwsgi.d/graphite-api.ini<< "EOF"
#[uwsgi]
#processes = 1
#socket = localhost:3035
#plugins = python
#pythonpath=/usr/share/graphite_api
#module = graphite_api.app:app
#env = GRAPHITE_API_CONFIG=/etc/graphite-api.yaml
#EOF
#

 ####INITIAL DATABAS
cd /opt/graphite/webapp/graphite/
python manage.py syncdb

# follow prompts to setup nginx user
chown -R nginx: /opt/graphite/storage/


#######################
#INSTALL GRAFNA
###############
cd /tmp
wget https://grafanarel.s3.amazonaws.com/builds/grafana-3.1.0-1468321182.x86_64.rpm
rpm -Uvh grafanarel.s3.amazonaws.com/builds/grafana-3.1.0-1468321182.x86_64.rpm
cd /etc/grafana
openssl req -x509 -newkey rsa:2048 -keyout cert.key -out cert.pem -days 3650 -nodes

#need add config grafana.ini


setcap 'cap_net_bind_service=+ep' /usr/sbin/grafana-server
systemctl enable grafana-server
systemctl start grafana-server
