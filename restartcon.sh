#!/bin/bash
# Script to generate a systemd service file to restart a Podman container on reboot.
#
# Usage: ./create-podman-restart-service.sh <container_name>
#
# Example: ./create-podman-restart-service.sh my-pihole-container

# Check if a container name is provided
if [ -z "$1" ]; then
  echo "Error: Please provide the name of the container to restart."
  echo "Usage: $0 <container_name>"
  exit 1
fi

container_name="$1"

# Check if the container exists
if ! podman ps -a --format "%%n" | grep -q "$container_name"; then
  echo "Error: Container '$container_name' not found.  Please ensure the container name is correct."
  echo "Available containers:"
  podman ps -a --format "  %%n"
  exit 1
fi

# Create the systemd service file
service_name="container-$container_name.service"
service_file="/etc/systemd/system/$service_name"

cat <<EOF > "$service_file"
[Unit]
Description=Podman container auto-restart service for $container_name
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/bin/podman start $container_name
ExecStop=/usr/bin/podman stop $container_name
Restart=on-failure
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
  echo "Successfully created systemd service file: $service_file"
else
  echo "Failed to create systemd service file."
  exit 1
fi

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable "$service_name"

if [ $? -eq 0 ]; then
  echo "Successfully enabled the systemd service.  The container '$container_name' will now restart on reboot."
  echo "You can start the service now with: sudo systemctl start $service_name"
  echo "You can check the service status with: sudo systemctl status $service_name"
else
  echo "Failed to enable the systemd service."
  exit 1
fi

exit 0

