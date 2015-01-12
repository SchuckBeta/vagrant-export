#!/bin/bash

echo "Cleaning application database tables"
DBS=$(echo 'SHOW DATABASES;' | mysql -u root | egrep -v 'Database|information_schema|performance_schema|mysql')

for DB in ${DBS}
do
    echo 'SHOW TABLES;' | \
        mysql -u root $DB | \
        egrep '^cf_|^index_|^tx_realurl|sys_log|sys_history|dataflow_batch_export|dataflow_batch_import|log_customer|log_quote|log_summary|log_summary_type|log_url|log_url_info|log_visitor|log_visitor_info|log_visitor_online|report_viewed_product_index|report_compared_product_index|report_event|index_event|catalog_compare_item' | \
        egrep -v 'index_stat|index_conf|realurl_redirect' | \
        awk '{print "TRUNCATE "$1";"}' | \
        mysql -u root $DB

done

echo "Reset vagrant authorized keys file"
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O '/home/vagrant/.ssh/authorized_keys'

echo "Removing old kernel packages"
apt-get -y --purge remove $(dpkg --list | grep '^rc' | awk '{print $2}')
apt-get -y --purge remove $(dpkg --list | egrep 'linux-(image|headers)-[0-9]' | awk '{print $3,$2}' | sort -nr | tail -n +2 | grep -v $(uname -r | sed -e s/-generic//g) | awk '{ print $2}')

echo "Cleaning up apt"
apt-get -y --purge autoremove
apt-get -y clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/aptitude/*

echo "Cleaning up home"
rm -rf $HOME/.cache
rm -rf $HOME/.local
rm -rf $HOME/.npm
rm -rf $HOME/tmp

if [[ -d /var/www/typo3temp ]]; then
    echo "Empty TYPO3 CMS temp files"
    find /var/www/typo3temp -type f -exec rm -f {} \;
    find /var/www/typo3temp -type d -iname "_processed_" -exec rm -rf {} \;
fi

if [[ -d /var/www/Data/Temporary ]]; then
    echo "Empty TYPO3 Flow temp files"
    rm -rf /var/www/Data/Temporary/*
fi

if [[ -d /var/www/var/cache ]]; then
    echo "Empty Magento temp files"
    rm -rf /var/www/downloader/.cache/*
    rm -rf /var/www/downloader/pearlib/cache/*
    rm -rf /var/www/downloader/pearlib/download/*
    rm -rf /var/www/var/cache/*
    rm -rf /var/www/var/locks/*
    rm -rf /var/www/var/log/*
    rm -rf /var/www/var/report/*
    rm -rf /var/www/var/session/*
    rm -rf /var/www/var/tmp/*
fi

echo "Zeroing device to make space..."
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

echo "Sync to disc"
sync

echo "Exit happily"
exit 0
