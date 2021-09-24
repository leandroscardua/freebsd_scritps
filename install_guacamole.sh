#!/bin/sh

############# Installation Folder Location ##########################
# /usr/local/share/guacamole-client = jar for the database connector
# /usr/local/etc/guacamole-client = GUACAMOLE_HOME folder
# /usr/local/etc/guacamole-server = Guacamole configuration server
# /usr/local/apache-tomcat-9.0/logs = Log folder
# tree /usr/local/share/guacamole-client
#.
#|-- extensions
#|   `-- guacamole-auth-jdbc-mysql-1.3.0.jar
#|-- guacamole.properties
#|-- guacamole.properties.sample
#|-- lib
#|   `-- mysql-connector-java.jar
#|-- logback.xml
#|-- logback.xml.sample
#`-- user-mapping.xml.sample
#####################################################################

#generate random password for root and guacamole db user
mysqlroot=$(openssl rand -base64 15)
guacamole_password=$(openssl rand -base64 15)

pkg install -y guacamole-server
pkg install -y guacamole-client
pkg install -y mysql80-server
pkg install -y mysql-connector-java

# add service to startup
echo 'guacd_enable="YES"' >> /etc/rc.conf
echo 'tomcat9_enable="YES"' >> /etc/rc.conf
echo 'mysql_enable="YES"' >> /etc/rc.conf

#create folder structure
mkdir /usr/local/etc/guacamole-client/lib
mkdir /usr/local/etc/guacamole-client/extensions

# extract java connector to guacamole
cp /usr/local/share/java/classes/mysql-connector-java.jar /usr/local/etc/guacamole-client/lib
tar xvfz /usr/local/share/guacamole-client/guacamole-auth-jdbc.tar.gz -C /tmp/
cp /tmp/guacamole-auth-jdbc-*/mysql/*.jar /usr/local/etc/guacamole-client/extensions

# configure guacamole server file
cp /usr/local/etc/guacamole-server/guacd.conf.sample /usr/local/etc/guacamole-server/guacd.conf
cp /usr/local/etc/guacamole-client/logback.xml.sample /usr/local/etc/guacamole-client/logback.xml
cp /usr/local/etc/guacamole-client/guacamole.properties.sample /usr/local/etc/guacamole-client/guacamole.properties

# Change default port Tomcat
sed -i -e 's/"8080"/"8085"/g' /usr/local/apache-tomcat-9.0/conf/server.xml

# Add database connection
echo "mysql-hostname: localhost" >> /usr/local/etc/guacamole-client/guacamole.properties
echo "mysql-port:     3306" >> /usr/local/etc/guacamole-client/guacamole.properties
echo "mysql-database: guacamole_db" >> /usr/local/etc/guacamole-client/guacamole.properties
echo "mysql-username: guacamole_user" >> /usr/local/etc/guacamole-client/guacamole.properties
echo "mysql-password: $guacamole_password" >> /usr/local/etc/guacamole-client/guacamole.properties

service mysql-server start

# Create username, password and database and change root password
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlroot}';CREATE DATABASE guacamole_db;CREATE USER 'guacamole_user'@'localhost' IDENTIFIED BY '${guacamole_password}';GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';FLUSH PRIVILEGES;";

# Apply schema to the database
cat /tmp/guacamole-auth-jdbc-*/mysql/schema/*.sql | mysql -u root -p"${mysqlroot}" guacamole_db

service mysql-server restart
service guacd restart
service tomcat9 restart

echo "
The default user for the Admin Portal is "guacadmin" with password "guacadmin"
Admin Portal: http://{IP_ Address}}:8085
MySQL Username: root
MySQL Password: "$mysqlroot"
Guacamole DB User: guacamole_user
Guacamole DB Password: "$guacamole_password"
"
