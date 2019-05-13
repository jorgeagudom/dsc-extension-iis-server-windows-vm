#!/bin/bash

sudo su

apt-get -y update

# install apache2
apt-get -y install apache2

# write some HTML
echo \<center\>\<h1\>Desarrollo Apache Web\</h1\>\<br/\>\</center\> > /var/www/html/demo.html

# restart Apache
apachectl restart