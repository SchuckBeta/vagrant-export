#!/bin/bash

echo "Removing old kernel packages"
apt-get -y --purge remove $(dpkg --list | grep '^rc' | awk '{print $2}')
apt-get -y --purge remove $(dpkg --list | egrep 'linux-image-[0-9]' | awk '{print $3,$2}' | sort -nr | tail -n +2 | grep -v $(uname -r) | awk '{ print $2}')

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
fi

if [[ -d /var/www/Data/Temporary ]]; then
    echo "Empty TYPO3 Flow temp files"
    rm -rf /var/www/Data/Temporary/*
fi

if [[ -d /var/www/downloader/.cache ]]; then
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

echo "Sync to disc"
sync

echo "Zeroing device to make space..."
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

echo "Exit happily"
exit 0
