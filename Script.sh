#!/bin/bash
echo "{
    \"http-basic\": {
       \"repo.magento.com\": {
            \"username\": \"f3dccb5e7a1b5e22a606c19f9c1eb641\",
            \"password\": \"fa677347b5a6a448494ade10a8649b19\"
        }
    }
}" > /tmp/auth.json
dnf update -y
wget https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh
sh virtualmin-install.sh --bundle LEMP
. /etc/os-release && dnf -y install https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %$ID).rpm && dnf clean all
dnf install php81-php-{cli,fpm,pdo,gd,mbstring,mysqlnd,opcache,xml,zip,bcmath,intl,sodium,soap} -y
dnf install php80-php-{cli,fpm,pdo,gd,mbstring,mysqlnd,opcache,xml,zip,bcmath,intl,sodium,soap} -y
dnf install php74-php-{cli,fpm,pdo,gd,mbstring,mysqlnd,opcache,xml,zip,bcmath,intl,sodium,soap} -y
dnf install php82-php-{cli,fpm,pdo,gd,mbstring,mysqlnd,opcache,xml,zip,bcmath,intl,sodium,random,soap} -y
dnf remove php-* -y
ln -s /opt/remi/php82/root/bin/php /usr/bin/php
sed -i 's/memory_limit = 128M/memory_limit = 2G/g' /etc/opt/remi/php82/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 1800/g' /etc/opt/remi/php82/php.ini
sed -i 's/zlib.output_compression = Off/zlib.output_compression = On/g' /etc/opt/remi/php82/php.ini
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/opt/remi/php82/php.ini
service php82-php-fpm restart
dnf install java-11-openjdk java-11-openjdk-devel -y
echo "[elasticsearch]

name=Elasticsearch repository for 7.x packages

baseurl=https://artifacts.elastic.co/packages/7.x/yum

gpgcheck=1

gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch

enabled=1

autorefresh=1

type=rpm-md" > /etc/yum.repos.d/elasticsearch.repo
dnf install elasticsearch -y
systemctl enable elasticsearch
systemctl start elasticsearch
read -p "Write the name of your domain/virtual-server:--" dom
read -p "write passwd for your domain :--" pass
read -p "write the emailid for your magento admin --" email
read -p "write passwd for magento admin :--" adminpass
echo "<===============================================================================================================================>
ALSO POINT YOUR A RECORD FOR THE DOMAIN
<===================================================================================================================================>"

sleep 5

uname=`echo $dom |awk -F"." '{print $1}'`
virtualmin create-domain --domain $dom --pass $pass --unix --dir --webmin  --dns --mysql --virtualmin-nginx --virtualmin-nginx-ssl --db $uname
virtualmin modify-domain --domain $dom --quota UNLIMITED
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/bin --filename=composer
su - $uname -c "mkdir -p  .config/composer"
su - $uname -c "cat /tmp/auth.json > .config/composer/auth.json"
su - $uname -c "composer create-project --repository=https://repo.magento.com/ magento/project-community-edition public_html/"
su - $uname -c "cd public_html && find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} +"
su - $uname -c "cd public_html && find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} +"
su - $uname -c "cd public_html && chmod u+x bin/magento "
socket=`ls -l /var/php-fpm/ | grep -i $uname | awk '{print $9}'`
su - $uname -c "cd public_html && sed -i 's/php-fpm:9000/unix:\/var\/php-fpm\/'$socket'/g' nginx.conf.sample "
su - $uname -c "public_html/bin/magento  setup:install \
--base-url=https://$dom \
--db-host=localhost \
--db-name=$uname \
--db-user=$uname \
--db-password=$pass \
--backend-frontname=admin \
--admin-firstname=admin \
--admin-lastname=admin \
--admin-email=$email \
--admin-user=admin \
--admin-password=$adminpass \
--language=en_US \
--currency=USD \
--timezone=America/Chicago \
--use-rewrites=1
"
su - $uname -c "public_html/bin/magento deploy:mode:set developer"
#socket=`ls -l /var/php-fpm/ | grep -i $uname | awk '{print $9}'`
#sed -i '84i upstream fastcgi_backend'$uname' {server  unix:/var/php-fpm/'$socket';}' /etc/nginx/nginx.conf
line=`grep -n "root /home/$uname/public_html" /etc/nginx/nginx.conf  | head -n1 |awk -F ":" '{print $1}'`
num=2
sum=$(($num + $line))
if [  $line -gt 0 ]
then
sed -i ''$line'i set $MAGE_ROOT /home/'$uname'/public_html;' /etc/nginx/nginx.conf
sed -i ''$line'i include /home/'$uname'/public_html/nginx.conf.sample;' /etc/nginx/nginx.conf
sed -i ''$sum'd' /etc/nginx/nginx.conf
else 
	echo "nothing" > /dev/null
fi
systemctl enable nginx 
systemctl restart nginx
