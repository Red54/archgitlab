#!/bin/bash

##########################
## Check if run as root ##
##########################

if [[ $EUID -ne 0 ]]; then
echo "This script must be run as root" 1>&2
exit 1
fi

##############################
## 1. Install prerequisites ##
##############################

cd
pacman -Syu --noconfirm
pacman -S --noconfirm --needed sudo git wget curl checkinstall libxml2 libxslt sqlite mysql++ base-devel zlib icu redis openssh python2 python2-pygments python2-pip libyaml ruby

## Add ruby exec to PATH ##

echo "export PATH=/root/.gem/ruby/1.9.1/bin:$PATH" >> /root/.bash_profile
source /root/.bashrc

#######################################
## 2. Install and configure gitolite ##
#######################################

## Add git and gitlab user ##

useradd --user-group --shell /bin/sh --comment 'git version control' --create-home --system git
useradd --user-group --shell /bin/bash --comment 'gitlab system' --create-home --groups git gitlab

sudo -H -u gitlab ssh-keygen -q -N '' -t rsa -f /home/gitlab/.ssh/id_rsa

cd /home/git
sudo -H -u git git clone git://github.com/gitlabhq/gitolite /home/git/gitolite

sudo -u git sh -c 'echo "export PATH=/home/git/bin:$PATH" >> /home/git/.bash_profile'
sudo -u git -H sh -c "export PATH=/home/git/bin:$PATH; /home/git/gitolite/src/gl-system-install"
sudo cp /home/gitlab/.ssh/id_rsa.pub /home/git/gitlab.pub
sudo chmod 0444 /home/git/gitlab.pub

sudo -u git -H sed -i 's/0077/0007/g' /home/git/share/gitolite/conf/example.gitolite.rc
sudo -u git -H sh -c "PATH=/home/git/bin:$PATH; gl-setup -q /home/git/gitlab.pub"

chmod -R g+rwX /home/git/repositories/
chmod g+x /home/git # (thanks to http://howto.basjes.nl/linux/installing-gitlab-on-centos-6#section-11)
chown -R git:git /home/git/repositories/

cd
sudo -u gitlab -H git clone git@localhost:gitolite-admin.git /tmp/gitolite-admin
# Answer yes. At this point you should be able to clone the gitolite-admin repository. This step is vital to succeed. If not do not try to proceed further.

rm -rf /tmp/gitolite-admin

##################################################################
## 3 Install and configure gitlab. Check status configuration. ##
##################################################################

## Add ruby exec to PATH ##
sudo -u gitlab -H sh -c 'echo "export PATH=/home/gitlab/.gem/ruby/1.9.1/bin:$PATH" >> /home/gitlab/.bash_profile'
#source /home/gitlab/.bashrc

sudo -u gitlab -H gem install bundler
sudo -u gitlab -H sh -c 'echo "export PATH=/home/gitlab/.gem/ruby/1.9.1/gems/bundler-1.1.5/bin/:$PATH" >> /home/gitlab/.bash_profile'
cd /home/gitlab
sudo -H -u gitlab git clone -b stable git://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab

sudo -u gitlab mkdir tmp

##############################################################################
## 3.1 Rename the main configiguration file and edit it to match your needs ##
##############################################################################

sudo -u gitlab cp config/gitlab.yml.example config/gitlab.yml

########################################################################
## 3.2 Select the DB you want to use by uncommenting mysql or sqlite ##
########################################################################

################################ SQLite ########################################
## 3.2a You don't have to create an sqlite DB, gitlab will create it for you. ##
################################################################################

#sudo -u gitlab cp config/database.yml.sqlite config/database.yml

################################ Mysql ############################################
## 3.2b A mysql database should already exist, gitlab won't create it for you. ##
## Change username/password of config/database.yml to the real one. ##
###################################################################################

#sudo -u gitlab cp config/database.yml.example config/database.yml

#######################
## 3.3 Install gems ##
#######################

cd /home/gitlab/gitlab
sudo -u gitlab -H bundle install --without development test --deployment

# Add python2.7 to ffi.rb (thanks to https://bbs.archlinux.org/viewtopic.php?pid=1143763#p1143763)
sed -i "s/opts = {})/opts = {:python_exe => 'python2.7'})/g" /home/gitlab/gitlab/vendor/bundle/ruby/1.9.1/bundler/gems/pygments.rb-2cada028da50/lib/pygments/ffi.rb


##################
## 3.4 Setup DB ##
##################

rc.d start redis
sudo -u gitlab bundle exec rake gitlab:app:setup RAILS_ENV=production

##### Default login/paddword #####
#                                #
# login.........admin@local.host #
# password......5iveL!fe         #
#                                #
##################################

#########################
## 3.5 Checking status ##
#########################

sudo -u gitlab bundle exec rake gitlab:app:status RAILS_ENV=production

### Output example ###

# ** Invoke gitlab:app:status (first_time)
# ** Invoke environment (first_time)
# ** Execute environment
# ** Execute gitlab:app:status
# Starting diagnostic
# config/database.yml............exists
# config/gitlab.yml............exists
# /home/git/repositories/............exists
# /home/git/repositories/ is writable?............YES
# remote: Counting objects: 12, done.
# remote: Compressing objects: 100% (8/8), done.
# remote: Total 12 (delta 1), reused 0 (delta 0)
# Receiving objects: 100% (12/12), 1.11 KiB, done.
# Resolving deltas: 100% (1/1), done.
# Can clone gitolite-admin?............YES
# UMASK for .gitolite.rc is 0007? ............YES
#
# Finished


