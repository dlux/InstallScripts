#!/bin/bash
# ============================================================================
# This script installs and configure jenkins for a linux server
# If already installed, it will update it.
# Optionally send proxy server.
# ============================================================================

# Uncomment the following line to debug
 set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================

[[ ! -f common_packages ]] && curl -O https://raw.githubusercontent.com/dlux/InstallScripts/master/common_packages

[[ ! -f common_packages ]] && echo 'Error. Unable to download common_packages.'

source common_packages

EnsureRoot

_NGINX=False
_APACHE=False
_HTTP_PORT=8080
_PASSWORD='secure123'

# ======================= Processes installation options =====================
while [[ $1 ]]; do
  case "$1" in
    --help|-h)
      read -d '' extraOptsH <<- EOM
\     --apache | -a     Install Apache proxy to forward port 80 to 8080.
     --nginx  | -n     Install Nginx proxy to forwqard port 80 to 8080.
     --password | -p   Use given password for jenkins and default Admin user.
EOM
      PrintHelp "Install & configure Jenkins" $(basename "$0") "$extraOptsH"
      ;;
    --apache|-a)
      _APACHE=True
      ;;
    --nginx|-n)
      _NGINX=True
      ;;
    --password|-p)
      [[ -z $2 ]] && PrintError "Password must be provided"
      _PASSWORD=$2
      shift
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ========================= Configuration Section ============================
[[ $_NGINX == True && $_APACHE == True ]] && PrintError "Select either nginx or apache as reverse proxy"

function configNginx {
    echo 'Configuring Nginx'
    rm /etc/nginx/sites-available/default
    rm /etc/nginx/sites-enabled/default
    cat <<EOF > "/etc/nginx/sites-available/jenkins"
upstream jenkins_server {
    server 127.0.0.1:$_HTTP_PORT fail_timeout=0;
}
 
server {
    listen 80;
    server_name localhost;
 
    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
 
        if (!-f \$request_filename) {
            proxy_pass http://jenkins_server;
            break;
        }
    }
}
EOF
    ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
    systemctl restart nginx
}

function configApache {
    echo 'Configuring Apache Proxy'
    a2dissite 000-default
    cat <<EOF > "/etc/apache2/sites-available"
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName localhost
    ServerAlias ci
    ProxyRequests Off
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>
    ProxyPreserveHost on
    ProxyPass / http://localhost:$_HTTP_PORT/ nocanon
    AllowEncodedSlashes NoDecode
</VirtualHost>

EOF
    a2ensite jenkins
    service apache2 restart
}

# ========================= Jenkins instalation ==============================
SetLocale /root
echo "Jenkins installation begins"
[[ ! -z "$_PROXY" ]] && source .PROXY

SetFirewallUFW

echo 'Installing Jenkins'
InstallJenkins
systemctl start jenkins

if [ $_NGINX == True ]; then
    echo 'Installing NGINX'
    InstallNginx
    configNginx
    # Open firewall on port 80
    ufw allow 'Nginx HTTP'
fi

if [ $_APACHE == True ]; then
    echo 'Installing Apache'
    InstallApache
    CustomizeApache
    InstallApacheMod 'proxy'
    configApache
    ufw allow 'apache2'
fi

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy $_ORIGINAL_PROXY
