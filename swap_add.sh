#!/bin/bash

# Adds a swapfile to the EC2 instance-storage on boot.
#
# Since the instance-storage is ephemeral, creating a swapfile
# and adding an fstab entry isn't enough to make the swapfile persist after shutdown.
#
# Instead, we don't create an fstab entry and just run this script on startup.

# Swapfile size in MB
SWAP_SIZE=4096

# Instance-storage directory, swapfile is stored here
# usually instance storage is a device like /dev/xvdb and mounts on /mnt by default
SWAP_DIR="/mnt"

# Swapfile name
SWAP_NAME="swapfile"

# Swapfile priority, higher priority numbers are used first by the kernel
SWAP_PRIORITY=1

TARGET="$SWAP_DIR/$SWAP_NAME"

activate_swap() {
    echo "swap_add: Activating swap on $TARGET..."
    /sbin/mkswap "$TARGET" || {
        echo "swap_add: mkswap failed on $TARGET"
        exit 1
    }
    /sbin/swapon -p $SWAP_PRIORITY "$TARGET" || {
        echo "swap_add: swapon failed on $TARGET"
        exit 1
    }
}

# Check if the swapfile already exists
if [ -f "$TARGET" ]; then
    echo "swap_add: Swapfile $TARGET already exists. Checking swap devices..."
    # Check if the file is being used as swap
    if ! /sbin/swapon -s | /bin/grep "$TARGET"; then
        echo "swap_add: Swapfile is not being used!"
        activate_swap
        exit 0
    else
        # Swapfile already exists and is active
        echo "swap_add: Swapfile already exists and is active, aborting..."
        exit 0
    fi
fi

# Swapfile doesn't exist, create a new one
echo "swap_add: Creating new swapfile $TARGET"
dd if=/dev/zero of="$TARGET" bs=1M count=$SWAP_SIZE || {
    echo "swap_add: Could not create swapfile $TARGET!"
    exit 1
}
echo "swap_add: ...done!"

echo "swap_add: Setting permissions on $TARGET"
chown root:root "$TARGET" && chmod 600 "$TARGET" || {
    echo "swap_add: Could not set permissions on $TARGET! Aborting and cleaning up..."
    rm "$TARGET"
    exit 1
}

activate_swap
exit $?
