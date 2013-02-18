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

# mysql or postgresql, default:mysql
DB='mysql'

# database name, default:gitlabhq_production
DB_NAME='gitlabhq_production' 

DB_ROOT_PASSWD=''
DB_GITLAB_PASSWD=''



##############################
## 1. Install prerequisites ##
##############################

pacman -Syu --noconfirm --needed sudo base-devel zlib libyaml openssl gdbm readline ncurses libffi curl git openssh redis postfix checkinstall libxml2 libxslt icu python2 mysql ruby


## Add ruby exec to PATH

echo "export PATH=/root/.gem/ruby/1.9.1/bin:$PATH" >> /root/.bash_profile
source /root/.bashrc


###########################
## 2. Configure database ##
###########################






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


#################################################################
## 3 Install and configure gitlab. Check status configuration. ##
#################################################################

    cd /home/git

## Clone the Source

    # Clone GitLab repository
    sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab

    # Go to gitlab dir 
    cd /home/git/gitlab
   
    # Checkout to stable release
    sudo -u git -H git checkout 5-0-stable

**Note:**
You can change `5-0-stable` to `master` if you want the *bleeding edge* version, but
do so with caution!

## Configure it

    cd /home/git/gitlab

    # Copy the example GitLab config
    sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

    # Make sure to change "localhost" to the fully-qualified domain name of your
    # host serving GitLab where necessary
    sudo -u git -H vim config/gitlab.yml

    # Make sure GitLab can write to the log/ and tmp/ directories
    sudo chown -R git log/
    sudo chown -R git tmp/
    sudo chmod -R u+rwX  log/
    sudo chmod -R u+rwX  tmp/

    # Create directory for satellites
    sudo -u git -H mkdir /home/git/gitlab-satellites

    # Create directory for pids and make sure GitLab can write to it
    sudo -u git -H mkdir tmp/pids/
    sudo chmod -R u+rwX  tmp/pids/
 
    # Copy the example Unicorn config
    sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb

**Important Note:**
Make sure to edit both files to match your setup.

## Configure GitLab DB settings

    # Mysql
    sudo -u git cp config/database.yml.mysql config/database.yml

    # PostgreSQL
    sudo -u git cp config/database.yml.postgresql config/database.yml

Make sure to update username/password in config/database.yml.

## Install Gems

    cd /home/git/gitlab

    sudo gem install charlock_holmes --version '0.6.9'

    # For MySQL (note, the option says "without")
    sudo -u git -H bundle install --deployment --without development test postgres

    # Or for PostgreSQL
    sudo -u git -H bundle install --deployment --without development test mysql


## Initialise Database and Activate Advanced Features
    
    sudo -u git -H bundle exec rake db:setup RAILS_ENV=production
    sudo -u git -H bundle exec rake db:seed_fu RAILS_ENV=production
    sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production


## Install Init Script

Download the init script (will be /etc/init.d/gitlab):

    sudo curl --output /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/init.d/gitlab
    sudo chmod +x /etc/init.d/gitlab

Make GitLab start on boot:

    sudo update-rc.d gitlab defaults 21


## Check Application Status

Check if GitLab and its environment are configured correctly:

    sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production

To make sure you didn't miss anything run a more thorough check with:

    sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

If all items are green, then congratulations on successfully installing GitLab!
However there are still a few steps left.

## Start Your GitLab Instance

    sudo service gitlab start
    # or
    sudo /etc/init.d/gitlab restart


# 7. Nginx

**Note:**
If you can't or don't want to use Nginx as your web server, have a look at the
[`Advanced Setup Tips`](./installation.md#advanced-setup-tips) section.

## Installation
    sudo apt-get install nginx

## Site Configuration

Download an example site config:

    sudo curl --output /etc/nginx/sites-available/gitlab https://raw.github.com/gitlabhq/gitlab-recipes/master/nginx/gitlab
    sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab

Make sure to edit the config file to match your setup:

    # Change **YOUR_SERVER_IP** and **YOUR_SERVER_FQDN**
    # to the IP address and fully-qualified domain name
    # of your host serving GitLab
    sudo vim /etc/nginx/sites-available/gitlab

## Restart

    sudo service nginx restart


# Done!

Visit YOUR_SERVER for your first GitLab login.
The setup has created an admin account for you. You can use it to log in:

    admin@local.host
    5iveL!fe

**Important Note:**
Please go over to your profile page and immediately chage the password, so
nobody can access your GitLab by using this login information later on.


-------OLD GUIDE---------


## Add ruby exec to PATH ##
sudo -u gitlab -H sh -c 'echo "export PATH=/home/gitlab/.gem/ruby/1.9.1/bin:$PATH" >> /home/gitlab/.bash_profile'
#source /home/gitlab/.bashrc

sudo -u gitlab -H gem install bundler
sudo -u gitlab -H sh -c 'echo "export PATH=/home/gitlab/.gem/ruby/1.9.1/gems/bundler-1.1.5/bin/:$PATH" >> /home/gitlab/.bash_profile'
cd /home/gitlab
sudo -H -u gitlab git clone -b stable git://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab


sudo -u gitlab cp config/gitlab.yml.example config/gitlab.yml

#######################################################################
## 3.2 Select the DB you want to use by uncommenting mysql or sqlite ##
#######################################################################


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


#########################
## 3.5 Checking status ##
#########################



##### Default login/password #####
#                                #
# login.........admin@local.host #
# password......5iveL!fe         #
#                                #
##################################
