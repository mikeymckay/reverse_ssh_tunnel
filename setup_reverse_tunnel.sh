#!/bin/bash
if [ -z "$SUDO_USER" ]; then
    echo "$0 must be called from sudo. Try: 'sudo ${0}'"
    exit 1
fi

SCRIPT_LOCATION="/etc/network/if-up.d/reverse_ssh_tunnel"

echo "Creating file in $SCRIPT_LOCATION"
echo "Installing openssh-server and autossh"
apt-get install openssh-server autossh
echo "Randomly creating port numbers (edit these in the file to change if you want)"

PORT_NUMBER=$[ ( $RANDOM % 10000 )  + 10000 ]
MONITORING_PORT_NUMBER=$[ ( $RANDOM % 10000 )  + 20000 ]

echo "PORT_NUMBER: ${PORT_NUMBER}"
echo "MONITORING_PORT_NUMBER: ${MONITORING_PORT_NUMBER}"
echo "Enter servername or IP address for the middleman server"
read MIDDLEMAN_SERVER
echo "Enter username to use for logging into $MIDDLEMAN_SERVER:[$SUDO_USER]"
read MIDDLEMAN_USERNAME
if [[ -z $MIDDLEMAN_USERNAME ]]; then
  MIDDLEMAN_USERNAME=$SUDO_USER
fi
echo "Checking to see if we can login using public key authentication: ssh $MIDDLEMAN_USERNAME@$MIDDLEMAN_SERVER (TODO, TO BE IMPLEMENTED!)"
su $SUDO_USER -c "ssh $MIDDLEMAN_USERNAME@$MIDDLEMAN_SERVER \"echo I am in\""

echo "Checking to see if GatewayPorts is set on $MIDDLEMAN_SERVER"
su $SUDO_USER -c "ssh $MIDDLEMAN_USERNAME@$MIDDLEMAN_SERVER \"cat /etc/ssh/sshd_config | grep 'GatewayPorts yes'\""

echo "Do you want to upload your public key to the middleman and setup public key authentication? ([y]/n)"
read COPY_KEY

if [ ! "${COPY_KEY}" = "n" ]; then
  su $SUDO_USER -c "ssh-copy-id $MIDDLEMAN_USERNAME@$MIDDLEMAN_SERVER"
fi

echo "#!/bin/sh
# ------------------------------
# Added by setup_reverse_tunnel.sh
# ------------------------------
# See autossh and google for reverse ssh tunnels to see how this works

# When this script runs it will allow you to ssh into this machine even if it is behind a firewall or has a NAT'd IP address. 
# From any ssh capable machine you just type ssh -p $PORT_NUMBER $SUDO_USER@$MIDDLEMAN_SERVER

# This is the username on your local server who has public key authentication setup at the middleman
USER_TO_SSH_IN_AS=$MIDDLEMAN_USERNAME

# This is the username and hostname/IP address for the middleman (internet accessible server)
MIDDLEMAN_SERVER_AND_USERNAME=$MIDDLEMAN_USERNAME@$MIDDLEMAN_SERVER

# Port that the middleman will listen on (use this value as the -p argument when sshing)
PORT_MIDDLEMAN_WILL_LISTEN_ON=$PORT_NUMBER

# Connection monitoring port, don't need to know this one
AUTOSSH_PORT=$MONITORING_PORT_NUMBER

# Ensures that autossh keeps trying to connect
AUTOSSH_GATETIME=0
su -c \"autossh -f -N -R *:\${PORT_MIDDLEMAN_WILL_LISTEN_ON}:localhost:22 \${MIDDLEMAN_SERVER_AND_USERNAME} -oLogLevel=error  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no\" $SUDO_USER
" > $SCRIPT_LOCATION

echo "Making script executable"
chmod +x $SCRIPT_LOCATION

echo "Tunnel will now automatically run whenever a network connection comes up"
echo "Do you want to start the tunnel now? [y]/n"
read START_TUNNEL

if [ ! "${START_TUNNEL}" = "n" ]; then
  $SCRIPT_LOCATION
fi

echo "You might want to add the following to your .ssh/config (and then copy it to other machines) so that you can set this up easily:

Host $HOSTNAME.tunnel
  Port $PORT_NUMBER
  HostName $MIDDLEMAN_SERVER
  User $MIDDLEMAN_USERNAME
"
