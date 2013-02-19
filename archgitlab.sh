#!/bin/bash

##########################
## Check if run as root ##
##########################

if [[ $EUID -ne 0 ]]; then
echo "This script must be run as root" 1>&2
exit 1
fi

######################################################################
## Before running this script, make sure to fill in these variables ##
######################################################################

# Enable or disable ruby docs installation
RUBY_DOCS_ENABLED=False

# mysql or postgresql
DB=mysql

# database name
DB_NAME=gitlabhq_production

DB_ROOT_PASSWD=
DB_GITLAB_PASSWD=
DB_GITLAB_USERNAME=

# Set branch to pull from
BRANCH=master

# Fully-qualified domain name
FQDN=


##############################
## 1. Install prerequisites ##
##############################

pacman -Syu --noconfirm --needed sudo base-devel zlib libyaml openssl gdbm readline ncurses libffi curl git openssh redis postfix checkinstall libxml2 libxslt icu python2 ruby

## Add ruby exec to PATH

echo "export PATH=/root/.gem/ruby/1.9.1/bin:$PATH" >> /root/.bash_profile
source /root/.bashrc


#####################################
## 3. Create a git user for Gitlab ##
#####################################

useradd --create-home --comment 'GitLab' git

#####################
## 3. GitLab shell ##
#####################

# Login as git 
su - git

# Clone gitlab shell
git clone https://github.com/gitlabhq/gitlab-shell.git

# Setup
cd gitlab-shell
cp config.yml.example config.yml
./bin/install 

exit

#################################################################
## 3 Install and configure GitLab. Check status configuration. ##
#################################################################

cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab/
   
# Checkout to stable release
sudo -u git -H git checkout $BRANCH

# Copy the example GitLab config
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

# Change "localhost" to the fully-qualified domain name 
sed -i "s/localhost/$FQDN/g" config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
chown -R git log/
chown -R git tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites

# Create directory for pids and make sure GitLab can write to it
sudo -u git -H mkdir tmp/pids/
sudo chmod -R u+rwX  tmp/pids/
 
# Copy the example Unicorn config
sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

# Start redis server
systemctl enable redis
systemctl start redis

## Configure GitLab DB settings / Install Gems

if [ RUBY_DOCS_ENABLED -eq False ]; then

    echo "gem: --no-rdoc --no-ri" >> /home/git/.gemrc

fi

gem install charlock_holmes --version '0.6.9'

if [[ $DB -eq 'mysql' ]]; then

    pacman -S --needed --noconfirm mysql
    sudo -u git cp config/database.yml.mysql config/database.yml
    sed -i "s/gitlabhq_production/$DB_NAME/" config/database.yml
    sed -i "s/root/$DB_GITLAB_USERNAME/" config/database.yml
    sed -i "s/secure password/$DB_GITLAB_PASSWD/" config/database.yml
    sudo -u git -H bundle install --deployment --without development test postgres
    
elif [[ $DB -eq 'postgresql' ]]; then 

    pacman -S --needed --noconfirm postgresql
    sudo -u git cp config/database.yml.postgresql config/database.yml
    sed -i "s/gitlabhq_production/$DB_NAME/" config/database.yml
    sed -i "s/gitlab/$DB_GITLAB_USERNAME/" config/database.yml
    sed -i 's/password:/password: $DB_GITLAB_PASSWD/' config/database.yml
    sudo -u git -H bundle install --deployment --without development test mysql
fi



## Initialise Database and Activate Advanced Features
sudo -u git -H bundle exec rake db:setup RAILS_ENV=production
sudo -u git -H bundle exec rake db:seed_fu RAILS_ENV=production
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production


## Check Application Status

# Check if GitLab and its environment are configured correctly

# sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

# To make sure you didn't miss anything run a more thorough check with

# sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production


# 7. Nginx

## Installation
pacman -S nginx

# Download an example site config
curl --output /etc/nginx/sites-available/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/nginx/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab

# Edit the config file to match your setup
sed -i "s/YOUR_SERVER_IP:80/80/" /etc/nginx/sites-available/gitlab
sed -i "s/YOUR_SERVER_FQDN/$FQDN/" /etc/nginx/sites-available/gitlab

# Restart and enable on boot
systemctl restart nginx
systemctl enable nginx


echo "Done!"
echo "Visit $FQDN for your first GitLab login."
echo "The setup has created an admin account for you."
echo "Please go over to your profile page and immediately change the password."
echo "##################################"
echo "## Email.....: admin@local.host ##"
echo "## Password..: 5iveL!fe         ##"
ehco "##################################"



-------OLD GUIDE---------


## Add ruby exec to PATH ##
sudo -u gitlab -H sh -c 'echo "export PATH=/home/gitlab/.gem/ruby/1.9.1/bin:$PATH" >> /home/gitlab/.bash_profile'
#source /home/gitlab/.bashrc


# Add python2.7 to ffi.rb (thanks to https://bbs.archlinux.org/viewtopic.php?pid=1143763#p1143763)
sed -i "s/opts = {})/opts = {:python_exe => 'python2.7'})/g" /home/gitlab/gitlab/vendor/bundle/ruby/1.9.1/bundler/gems/pygments.rb-2cada028da50/lib/pygments/ffi.rb


##################
## 3.4 Setup DB ##
##################

rc.d start sudo -u gitlab bundle exec rake gitlab:app:setup RAILS_ENV=production


#########################
## 3.5 Checking status ##
#########################



