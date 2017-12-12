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
_USER='dlux'
_NAME='Luz Cazares'
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

function configJenkins {

    # Make jenkis to skip initial setup wizard
    sed -i "s/^JAVA_ARGS=\"/JAVA_ARGS=\"-Djenkins.install.runSetupWizard=false /g" /etc/default/jenkins

    # Create a jenkins admin account which will replace intial Admin one
    mkdir -p /var/lib/jenkins/init.groovy.d
    cat <<EOF > "/var/lib/jenkins/init.groovy.d/basic-security.groovy"
#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> creating local user $_USER"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('$_USER', '$_PASSWORD')
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()

EOF

    # Set proxy
    px="$_ORIGINAL_PROXY"
    if [ ! -z $px ]; then
        protocol=$(echo $px | awk -F ':' '{print $1}')
        svr=$(echo $px | awk -F '://' '{print $2}' | awk -F ':' '{print $1}')
        port=$(echo $px | awk -F '://' '{print $2}' | awk -F ':' '{print $2}')
        sed -i "s/^JAVA_ARGS\=\"/JAVA_ARGS=\"\-Dhttp\.proxyHost\=$protocol\:\/\/$svr -Dhttp\.proxyPort\=$port /g" /etc/default/jenkins
        cat <<EOF >> "/var/lib/jenkins/init.groovy.d/basic-security.groovy"
final def pc = new hudson.ProxyConfiguration('$svr', $port, '', '', '$npx')
instance.proxy = pc
pc.save()
instance.save()

EOF
    fi
    systemctl restart jenkins
    WaitForJenkinsSvr $_HTTP_PORT 100

    curl -L http://updates.jenkins-ci.org/update-center.json | sed '1d;$d' | curl -X POST -H 'Accept: application/json' -d @- http://localhost:8080/updateCenter/byId/default/postBack

    # Install default jenkins plugins
    echo "Installing Default Jenkins Plugins"
    IFS=' ' read -r -a DEFAULT_PLUGINS <<< "build-timeout credentials credentials-binding durable-task email-ext external-monitor-job git git-client github github-api github-branch-source github-organization-folder git-server gradle handlebars icon-shim javadoc jquery-detached junit ldap mailer mapdb-api matrix-auth matrix-project momentjs pam-auth pipeline-build-step pipeline-input-step pipeline-rest-api pipeline-stage-step pipeline-stage-view plain-credentials scm-api script-security ssh-credentials ssh-slaves timestamper workflow-aggregator workflow-api workflow-basic-steps workflow-cps workflow-cps-global-lib workflow-durable-task-step workflow-job workflow-multibranch workflow-scm-step workflow-step-api workflow-support ws-cleanup"
    for plugin in "${DEFAULT_PLUGINS[@]}"
    do
       java -jar /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar \
           -s http://localhost:$_HTTP_PORT/ install-plugin "$plugin" \
           --username $_USER --password $_PASSWORD
    done
    sleep 10

    # Disable jenkins CLI
    echo 'Disabling jenkins CLI'
    sed -i "s/^JAVA_ARGS\=\"/JAVA_ARGS=\"\-Djenkins.CLI.disabled=true /g" /etc/default/jenkins

    # Disable deprecated protocols
    read -r -d '' lines << EOM
  <disabledAgentProtocols>
    <string>JNLP1-connect</string>
    <string>JNLP2-connect</string>
    <string>JNLP3-connect</string>
  </disabledAgentProtocols>
  <label></label>
  <crumbIssuer class="hudson.security.csrf.DefaultCrumbIssuer">
    <excludeClientIPFromCrumb>true</excludeClientIPFromCrumb>
  </crumbIssuer>
EOM
    sed -i "s/\<label\>\<\/label\>/$lines/g"
    systemctl restart jenkins
    WaitForJenkinsSvr $_HTTP_PORT 5
}

# ========================= Jenkins instalation ==============================
SetLocale /root
echo "Jenkins installation begins"
[[ ! -z "$_PROXY" ]] && source .PROXY

SetFirewallUFW
[[ $_NGINX == False && $_APACHE == False ]] && ufw allow $_HTTP_PORT

echo "Installing Jenkins on Port $_HTTP_PORT"
InstallJenkins $_HTTP_PORT
configJenkins

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
