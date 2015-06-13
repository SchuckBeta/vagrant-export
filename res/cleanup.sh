#!/bin/bash

echo "Cleaning application database tables"
DBS=$(echo 'SHOW DATABASES;' | mysql -u root | egrep -v 'Database|information_schema|performance_schema|mysql')

for DB in ${DBS}
do
    echo 'SHOW TABLES;' | \
        mysql -u root $DB | \
        egrep '^cf_|^cache_|^cachingframework_|^index_|^tx_realurl|sys_log|sys_history|dataflow_batch_export|dataflow_batch_import|log_customer|log_quote|log_summary|log_summary_type|log_url|log_url_info|log_visitor|log_visitor_info|log_visitor_online|report_viewed_product_index|report_compared_product_index|report_event|index_event|catalog_compare_item' | \
        egrep -v 'index_stat|index_conf|realurl_redirect' | \
        awk '{print "TRUNCATE "$1";"}' | \
        mysql -u root $DB
done

echo "Removing old kernel packages"
apt-get -qq -y --purge remove $(dpkg --list | egrep '^rc' | awk '{print $2}')
apt-get -qq -y --purge remove $(dpkg --list | egrep '^i' | egrep 'linux-(image(-extra)?|headers)-[0-9]' | awk '{print $3,$2}' | grep -v $(uname -r | sed -e s/-generic//g) | awk '{print $2}')

echo "Cleaning up apt"
apt-get -qq -y --purge autoremove
apt-get -qq -y clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/aptitude/*

echo "Cleaning up home"
rm -rf $HOME/.cache
rm -rf $HOME/.local
rm -rf $HOME/.npm
rm -rf $HOME/.composer
rm -rf $HOME/tmp

if [[ -d /www ]]; then
    DOCROOT="/www"
elif [[ -d /var/www/html ]]; then
    DOCROOT="/var/www/html"
else
    DOCROOT="/var/www"
fi

echo "Cleaning up document root ${DOCROOT}"

if [[ -d ${DOCROOT}/typo3temp ]]; then
    echo "Removing TYPO3 CMS temp files"
    find ${DOCROOT}/typo3temp -type f -exec rm -f {} \;

    if [[ -d ${DOCROOT}/fileadmin/_processed_ ]]; then
        rm -rf ${DOCROOT}/fileadmin/_processed_/* > /dev/null 2>&1
    fi
fi

if [[ -d ${DOCROOT}/Data/Temporary ]]; then
    echo "Removing TYPO3 Flow temp files"
    rm -rf ${DOCROOT}/Data/Temporary/* > /dev/null 2>&1
fi

if [[ -d /var/www/var/cache ]]; then
    echo "Removing Magento temp files"
    rm -rf ${DOCROOT}/downloader/.cache/*
    rm -rf ${DOCROOT}/downloader/pearlib/cache/*
    rm -rf ${DOCROOT}/downloader/pearlib/download/*
    rm -rf ${DOCROOT}/var/cache/*
    rm -rf ${DOCROOT}/var/locks/*
    rm -rf ${DOCROOT}/var/log/*
    rm -rf ${DOCROOT}/var/report/*
    rm -rf ${DOCROOT}/var/session/*
    rm -rf ${DOCROOT}/var/tmp/*
fi

echo "Zeroing device to make space..."
dd if=/dev/zero of=/EMPTY bs=1M > /dev/null 2>&1
sync
rm -f /EMPTY
sync

exit 0
