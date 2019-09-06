#!/bin/bash

echo "=========================================================="
echo "INSTALLING DONATION KIOSK..."
echo "NOTE: you will probably need to accept some of the"
echo "      apt-get installations (simply type 'Y' and hit ENTER)"
echo "NOTE2: this installation can keep hanging in"
echo "       Processing triggers for man-db (*) for some time"
echo "=========================================================="

## Build the cgi script

echo "----------------------------------------------------------"
echo "Building CGI..."
echo "----------------------------------------------------------"

cd CGI
chmod +x make.sh
./make.sh

## Remove mouse pointer with this script

echo "----------------------------------------------------------"
echo "Installing unclutter for mouse pointer removal..."
echo "----------------------------------------------------------"

apt-get install unclutter
unclutter

## Setup apache

echo "----------------------------------------------------------"
echo "Installing apache2..."
echo "----------------------------------------------------------"

apt-get install apache2

echo "----------------------------------------------------------"
echo "Creating symlink..."
echo "----------------------------------------------------------"

ln -t /etc/apache2/mods-enabled -s /etc/apache2/mods-available/cgi.load

echo "----------------------------------------------------------"
echo "Setting up CGI and static webpage directory..."
echo "----------------------------------------------------------"

printf "\n\n<Directory /var/www/html/>\n    Options -Indexes +ExecCGI\n    AddHandler cgi-script .bin\n</Directory>" >> /etc/apache2/sites-enabled/000-default.conf

## Back to root directory
cd ..

## Copy the CGI and static page

echo "----------------------------------------------------------"
echo "Copying CGI and webpage..."
echo "----------------------------------------------------------"

cp CGI/process_donation.bin /var/www/html
cp webpage/index.html /var/www/html

## Restart apache2

echo "----------------------------------------------------------"
echo "Restarting apache..."
echo "----------------------------------------------------------"

/etc/init.d/apache2 restart

## Get current directory
CURR_DIR=$(pwd)

## Put cashless daemon start into rc.local

echo "----------------------------------------------------------"
echo "Setting up autorun on boot for cashless master daemon..."
echo "----------------------------------------------------------"

# Make startup.sh executable
chmod +x startup.sh

RCLINES=$(wc -l < /etc/rc.local)

echo $RCLINES

if [ "$RCLINES" -lt 2 ]
then
	RCLINES=2
fi

RCLINES=$(($RCLINES-1))

LINE_PUT1=$(printf "%si./startup.sh" "$RCLINES")
echo $LINE_PUT1
sed -i "$LINE_PUT1" /etc/rc.local

LINE_PUT2=$(printf "%sicd %s" "$RCLINES" "$CURR_DIR")
echo $LINE_PUT2
sed -i "$LINE_PUT2" /etc/rc.local

## Add entries to autostart

echo "----------------------------------------------------------"
echo "Setting up autorun on boot for chromium-browser..."
echo "----------------------------------------------------------"

sh -c 'printf "\n@unclutter" >> /etc/xdg/lxsession/LXDE-pi/autostart'
sh -c 'printf "\n@export DISPLAY=:0" >> /etc/xdg/lxsession/LXDE-pi/autostart'
sh -c 'printf "\n@/usr/bin/chromium-browser --incognito --kiosk http://127.0.0.1" >> /etc/xdg/lxsession/LXDE-pi/autostart'
sh -c 'printf "\n@xset s noblank" >> /etc/xdg/lxsession/LXDE-pi/autostart'
sh -c 'printf "\n@xset s off" >> /etc/xdg/lxsession/LXDE-pi/autostart'
sh -c 'printf "\n@xset -dpms" >> /etc/xdg/lxsession/LXDE-pi/autostart'

echo "----------------------------------------------------------"
echo "Everything installed! Only thing left to do is a reboot!"
echo "----------------------------------------------------------"