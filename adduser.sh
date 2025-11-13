#!/bin/bash

# Create new user
useradd -m -d /home/$USERVPS $USERVPS

# Create password for USERVPS
echo "$USERVPS:$PASSVPS" | sudo chpasswd

# Add USERVPS to sudoers
sudo sed -i "\$a$USERVPS    ALL=(ALL) NOPASSWD: ALL" /etc/sudoers

# Disable root login via SSH 
sudo sed -i "/PermitRootLogin/d" /etc/ssh/sshd_config
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null


# Restart service SSH
sudo systemctl restart sshd
sudo systemctl restart ssh

# Add command to bashrc
echo "sudo -i" >> /home/$USERVPS/.bashrc

# Change default shell USERVPS
sudo chsh -s /bin/bash $USERVPS


echo "Finish"
