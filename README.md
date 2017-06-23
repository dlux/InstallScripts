# InstallScripts

This project contains individual shell scripts to 
automatically install different software and its dependencies.

###How to run scripts

```bash
  git clone https://github.com/dlux/InstallScripts.git
  cd InstallScripts
  ./install_ANY_FILE --help
```


**Use _--help | -h_ on any script to get further information on how to use it.**

###Content:

* common_functions         -  Miscellaneous functions e.x. validateIp
* common_packages          -  Miscellaneous package installation e.x. MySql
* devtools.cloudinit       -  Install devtools via cloudinit template
* _Example_Vagrantfile     -  Vagrantfile template - showing how to consume scripts on this repo

* get_proxy.sh - Prints the proxy data gather from a given file.
* clone_git_repos.sh       -  Clone common git repositories - OpenStack
* install_devtools.sh      -  Install python/OS development tools
* install_docker.sh        -  Install docker via *get.docker.com* - Containers
* install_docker_ubuntu.sh -  Install docker on Ubuntu via *apt-get*.
* install_kanboard.sh      -  Install kanboard server - For project management
* install_openstackid      -  Setup a server fot authentication via openid *UNDER-DEV*
* install_puppet.sh        -  Installs Puppet 3.7.5, Puppet-Librarian 1.0.3, and Ruby 1.9. *TOBEUPDATED*
* install_znc.sh           -  Install znc IRC bouncer
* refstack/                -  Install refstack server - openstack interop results
                              script + Vagrantfile
* setup_proxy.sh - Make system changes in order to configure given proxy information (e.g bashrc, apt.conf, or yum.conf).

Others:

*SOON TO BE MOVED TO OPENSTACK-AIO REPO*

* install_openstack_aio.sh
* my_devstack.sh - Installs devstack on a VM
