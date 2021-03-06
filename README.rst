==============
InstallScripts
==============

.. image:: https://travis-ci.com/dlux/InstallScripts.svg?branch=master
    :target: https://travis-ci.com/dlux/InstallScripts

This project contains individual shell scripts to 
automatically install different software and its dependencies.

How to run a scripts
--------------------

.. code-block:: Bash
 
  $ git clone https://github.com/dlux/InstallScripts.git
  $ pushd InstallScripts
  $ ./install_<ANY_SW> --help

  **NOTE:** Use _--help | -h_ on any script to get further information on how to use it.

**Scripts with 'T' means that are included in Travis CI tests**

Content:
--------

* **(T)** common_functions    -  Miscellaneous functions e.g. ValidateIp.
* common_packages             -  Miscellaneous package installation e.g. MySql.
* clone_git_repos.sh          -  Clone common git repositories - OpenStack
* devtools.cloudinit          -  Install devtools via cloudinit template.
* _Example_Vagrantfile        -  Vagrantfile template: shows how to use scripts from this repo.
* get_proxy.sh                -  Sets proxy data from a given file.
* install_booked.sh           -  Installl booked opensource project.
* install_cobbler.sh          -  Install cobbler baremetal installer.
* install_devtools.sh         -  Install python/OS development tools.
* **(T)** install_docker.sh   -  Install docker via *get.docker.com* - Containers
* **(T)** install_ftp.sh      -  Install and configure an ftp server
* **(T)** install_jekyll.sh   -  Install jekyll (markdown to blog site)
* install_jenkins.sh          -  Install jenkins on Ubuntu.
* install_kanboard.sh         -  Install kanboard server - For project management
* install_openstackid         -  Setup a server fot authentication via openid *UNDER-DEV*
* install_puppet.sh           -  Installs Puppet 3.7.5, Puppet-Librarian 1.0.3, and Ruby 1.9. *TOBEUPDATED*
* install_refstack            -  Install refstack server - See also https://github.com/dlux/vagrant-refstack
* install_znc.sh              -  Install znc IRC bouncer
* setup_proxy.sh              -  Make system configurations of given proxy (e.g bashrc, apt.conf, or yum.conf)

Others:
-------

* upgrade_ubuntu14to16.sh  -  Migrate running Ubuntu server from Trusty(14.04 LTS) to Xenial(16.04 LTS).
* usb_bootable.sh          -  Create a bootable usb given an ISO, a device, and a sha25sums.
* .vimrc                   -  Some basic setup for vim editor.
* xenial_usb.sh            -  Create bootable usb with Ubuntu Xenial 16.04 LTS(not tested).

TODO: SOON TO BE MOVED TO OPENSTACK-AIO REPO
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* install_openstack_aio.sh
* my_devstack.sh - Installs devstack on a VM
* minimal_devstack_sles.sh

