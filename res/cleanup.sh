#!/bin/bash -eux

# Removing old kernel packages
apt-get -y --purge remove $(dpkg --list | grep '^rc' | awk '{print $2}')
apt-get -y --purge remove $(dpkg --list | egrep 'linux-image-[0-9]' | awk '{print $3,$2}' | sort -nr | tail -n +2 | grep -v $(uname -r) | awk '{ print $2}')

# Cleaning up apt
apt-get -y --purge autoremove
apt-get -y clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/aptitude/*

# Cleaning up home
rm -rf $HOME/.cache
rm -rf $HOME/.local
rm -rf $HOME/.npm
rm -rf $HOME/tmp

# Empty TYPO3 CMS temp files
if [[ -d /var/www/typo3temp ]]; then
    find /var/www/typo3temp -type f -exec rm -f {} \;
fi

# Empty Flow temp files
if [[ -d /var/www/Data/Temporary ]]; then
    rm -rf /var/www/Data/Temporary
fi


# Empty Magento temp files
if [[ -d /var/www/downloader/.cache ]]; then
    rm -rf /var/www/downloader/.cache/*
fi

if [[ -d /var/www/downloader/pearlib/cache ]]; then
    rm -rf /var/www/downloader/pearlib/cache/*
fi

if [[ -d /var/www/downloader/pearlib/download ]]; then
    rm -rf /var/www/downloader/pearlib/download/*
fi

if [[ -d /var/www/var/cache ]]; then
    rm -rf /var/www/var/cache/*
fi

if [[ -d /var/www/var/locks ]]; then
    rm -rf /var/www/var/locks/*
fi

if [[ -d /var/www/var/log ]]; then
    rm -rf /var/www/var/log/*
fi

if [[ -d /var/www/var/report ]]; then
    rm -rf /var/www/var/report/*
fi

if [[ -d /var/www/var/cache ]]; then
    rm -rf /var/www/var/cache/*
fi

if [[ -d /var/www/var/session ]]; then
    rm -rf /var/www/var/session/*
fi

if [[ -d /var/www/var/tmp ]]; then
    rm -rf /var/www/var/tmp/*
fi


# Empty tmp
rm -rf /tmp/*

# Make sure we sync before the next step
sync

# Zero out the free space to save space in the final image:
echo "Zeroing device to make space..."
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

exit 0
