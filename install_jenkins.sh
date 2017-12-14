#!/bin/bash
# ============================================================================
# This script installs and configure jenkins for a linux server
# If already installed, it will update it.
# Optionally send proxy server.
# ============================================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================

[[ ! -f common_packages ]] && curl -O https://raw.githubusercontent.com/dlux/InstallScripts/master/common_packages

[[ ! -f common_packages ]] && echo 'Error. Unable to download common_packages.'

source common_packages

EnsureRoot

_APACHE=False
_HTTP_PORT=8080
_NGINX=False
_PASSWORD='secure123'
_USER='dlux'

# ======================= Processes installation options =====================
while [[ $1 ]]; do
  case "$1" in
    --help|-h)
      read -d '' extraOptsH <<- EOM
\      --apache  | -a   Install Apache. Use port 80 to proxy to <JenkinsPort>.
     --nginx    | -n   Install Nginx. Use port 80 to proxy to <JenkinsPort>.
     --password | -pw  Password for new admin user.
     --port     | -p   JenkinsPort for UI & services. Default to 8080.
     --user     | -u   User for new jenkins admin. Default to dlux.
EOM
      PrintHelp "Install & configure Jenkins" $(basename "$0") "$extraOptsH"
      ;;
    --apache|-a)
      _APACHE=True
      ;;
    --nginx|-n)
      _NGINX=True
      ;;
    --password|-pw)
      [[ -z $2 ]] && PrintError "Password must be provided"
      _PASSWORD=$2
      shift
      ;;
    --port|-p)
      [[ -z $2 ]] && PrintError "Port where Jenkins will run must be provided"
      _HTTP_PORT=$2
      shift
      ;;
    --user|-u)
      [[ -z $2 ]] && PrintError "User must be provided"
      _USER=$2
      shift
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ========================= Configuration Section ============================
# If ENV_VARr http_proxy, expand it
[[ -n $http_proxy ]] && SetProxy $http_proxy

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

    # Hardening Jenkins
    # Create new admin account, disable deprecated protocols, use CSRF issuer
    mkdir -p /var/lib/jenkins/init.groovy.d
    cat <<EOF > "/var/lib/jenkins/init.groovy.d/basic-security.groovy"
#!groovy

import jenkins.*
import jenkins.model.*
import jenkins.security.s2m.*
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

println "--> Turn on Agent to master security subsystem"

instance.injector.getInstance(AdminWhitelistRule.class)
    .setMasterKillSwitch(false);
instance.save()

println "--> Enabling non-deprecated Agent Protocols"

Set pToEnable = [];

for (AgentProtocol p : AgentProtocol.all())
  if (p.getName()!=null && p.isDeprecated()==false)
    pToEnable.add(p.getName());

println "--> Protocols to Enable \$pToEnable"
//Enable only non-deprecated protocols
instance.setAgentProtocols(pToEnable)
println "    Current enabled protocols: \${instance.getAgentProtocols()}"
instance.save()

println "--> Set CSRF issuer"
instance.setCrumbIssuer(new hudson.security.csrf.DefaultCrumbIssuer(true))
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
println "--> Setting up proxy $svr:$port for Jenkins"
final def pc = new hudson.ProxyConfiguration('$svr', $port, '', '', '$npx')
instance.proxy = pc
pc.save()
instance.save()

EOF
    fi
    systemctl restart jenkins
    WaitForJenkinsSvr 100
    sleep 10

    # Install default plugins
    cat <<EOF >> "/var/lib/jenkins/init.groovy.d/basic-security.groovy"
println "--> Installing default plugins."
def defaultPlugins = ['build-timeout', 'credentials', 'credentials-binding', 'durable-task', 'email-ext', 'external-monitor-job', 'git', 'git-client', 'github', 'github-api', 'github-branch-source', 'github-organization-folder', 'git-server', 'gradle', 'handlebars', 'icon-shim', 'javadoc', 'jquery-detached', 'junit', 'ldap', 'mailer', 'mapdb-api', 'matrix-auth', 'matrix-project', 'momentjs', 'pam-auth', 'pipeline-build-step', 'pipeline-input-step', 'pipeline-rest-api', 'pipeline-stage-step', 'pipeline-stage-view', 'plain-credentials', 'scm-api', 'script-security', 'ssh-credentials', 'ssh-slaves', 'timestamper', 'workflow-api', 'workflow-aggregator', 'workflow-basic-steps', 'workflow-cps', 'workflow-job', 'workflow-cps-global-lib', 'workflow-durable-task-step', 'workflow-multibranch', 'workflow-scm-step', 'workflow-step-api', 'workflow-support', 'ws-cleanup']

println "    Refreshing updateCenter."
def uCenter = instance.getUpdateCenter()
uCenter.updateDefaultSite()
uCenter.updateAllSites()
sleep(10)

println "    Installing plugins - May take a minute. \${defaultPlugins}"
instance.getPluginManager().install(defaultPlugins, true)
sleep(50)
println "--> Installed plugins: \${instance.getPluginManager().plugins}"
instance.save()

EOF

    # Disable jenkins CLI
    echo 'Disabling jenkins CLI'
    sed -i "s/^JAVA_ARGS\=\"/JAVA_ARGS=\"\-Djenkins.CLI.disabled=true /g" /etc/default/jenkins
    systemctl restart jenkins
    WaitForJenkinsSvr 100
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
