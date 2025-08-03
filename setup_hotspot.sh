#!/bin/bash

# Raspberry Pi WiFi Hotspot Setup Script
# A comprehensive script for setting up a WiFi access point

set -e

# Configuration variables - CUSTOMIZE THESE
SSID="MyHotspot"
PASSWORD="MySecurePassword123"
INTERFACE="wlan0"
IP_ADDRESS="192.168.4.1"
DHCP_RANGE_START="192.168.4.2"
DHCP_RANGE_END="192.168.4.20"
CHANNEL="7"
COUNTRY_CODE="US"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}$1${NC}"; }

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root (use sudo)"
        exit 1
    fi
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running on Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_warning "This script is designed for Raspberry Pi. It may work on other systems but is not tested."
    fi
    
    # Check if WiFi interface exists
    if ! ip link show $INTERFACE &>/dev/null; then
        print_error "WiFi interface $INTERFACE not found. Please check your hardware."
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        print_warning "No internet connection detected. Some features may not work."
    else
        print_status "Internet connection confirmed"
    fi
}

# Function to update system
update_system() {
    print_status "Updating system packages..."
    apt-get update
    apt-get upgrade -y
}

# Function to install required packages
install_packages() {
    print_status "Installing required packages..."
    apt-get install -y hostapd dnsmasq iptables-persistent netfilter-persistent
}

# Function to backup original configurations
backup_configs() {
    print_status "Backing up original configurations..."
    
    # Create backup directory
    mkdir -p /etc/hotspot-backup/$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="/etc/hotspot-backup/$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing configurations
    [ -f /etc/dnsmasq.conf ] && cp /etc/dnsmasq.conf $BACKUP_DIR/
    [ -f /etc/hostapd/hostapd.conf ] && cp /etc/hostapd/hostapd.conf $BACKUP_DIR/
    [ -f /etc/network/interfaces ] && cp /etc/network/interfaces $BACKUP_DIR/
    
    print_status "Backups saved to $BACKUP_DIR"
}

# Function to configure network interface
configure_network() {
    print_status "Configuring network interface..."
    
    # Create interfaces.d directory if it doesn't exist
    mkdir -p /etc/network/interfaces.d
    
    # Configure wlan0
    cat > /etc/network/interfaces.d/$INTERFACE << EOF
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    network 192.168.4.0
    broadcast 192.168.4.255
EOF
}

# Function to configure hostapd
configure_hostapd() {
    print_status "Configuring hostapd..."
    
    cat > /etc/hostapd/hostapd.conf << EOF
# WiFi Hotspot Configuration
interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
country_code=$COUNTRY_CODE
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0

# Security settings
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Additional settings
beacon_int=100
dtim_period=2
max_num_sta=50
EOF
}

# Function to configure dnsmasq
configure_dnsmasq() {
    print_status "Configuring dnsmasq..."
    
    cat > /etc/dnsmasq.conf << EOF
# DHCP and DNS Configuration
interface=$INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,24h

# DNS settings
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1

# Additional settings
domain-needed
bogus-priv
no-resolv
no-poll
cache-size=1000
EOF
}

# Function to enable IP forwarding
enable_ip_forwarding() {
    print_status "Enabling IP forwarding..."
    
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
}

# Function to configure NAT rules
configure_nat() {
    print_status "Configuring NAT rules..."
    
    # Flush existing rules
    iptables -F
    iptables -t nat -F
    
    # Add NAT rules
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i $INTERFACE -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Save iptables rules
    iptables-save > /etc/iptables.rules
    
    # Enable netfilter-persistent
    systemctl enable netfilter-persistent
}

# Function to start services
start_services() {
    print_status "Starting services..."
    
    # Stop any existing services
    systemctl stop hostapd dnsmasq 2>/dev/null || true
    
    # Unmask and enable hostapd
    systemctl unmask hostapd
    systemctl enable hostapd
    systemctl enable dnsmasq
    
    # Start services
    systemctl start hostapd
    systemctl start dnsmasq
    
    # Wait a moment for services to start
    sleep 3
}

# Function to verify setup
verify_setup() {
    print_status "Verifying setup..."
    
    local errors=0
    
    # Check if services are running
    if systemctl is-active --quiet hostapd; then
        print_status "✓ hostapd is running"
    else
        print_error "✗ hostapd is not running"
        ((errors++))
    fi
    
    if systemctl is-active --quiet dnsmasq; then
        print_status "✓ dnsmasq is running"
    else
        print_error "✗ dnsmasq is not running"
        ((errors++))
    fi
    
    # Check IP forwarding
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -eq 1 ]; then
        print_status "✓ IP forwarding is enabled"
    else
        print_error "✗ IP forwarding is not enabled"
        ((errors++))
    fi
    
    # Check interface
    if ip addr show $INTERFACE | grep -q $IP_ADDRESS; then
        print_status "✓ Network interface configured correctly"
    else
        print_error "✗ Network interface not configured correctly"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        print_status "✓ All checks passed!"
    else
        print_warning "Some issues detected. Check the logs for details."
    fi
}

# Function to display final information
display_info() {
    echo
    print_header "=========================================="
    print_header "WiFi Hotspot Setup Complete!"
    print_header "=========================================="
    echo
    echo "SSID: $SSID"
    echo "Password: $PASSWORD"
    echo "IP Address: $IP_ADDRESS"
    echo "DHCP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
    echo "Channel: $CHANNEL"
    echo
    echo "To connect to your hotspot:"
    echo "1. Look for '$SSID' in your WiFi networks"
    echo "2. Enter password: $PASSWORD"
    echo "3. Your device will get an IP from $DHCP_RANGE_START to $DHCP_RANGE_END"
    echo
    echo "Useful commands:"
    echo "- Check connected devices: sudo arp -a"
    echo "- View DHCP leases: sudo cat /var/lib/misc/dnsmasq.leases"
    echo "- Monitor logs: sudo journalctl -u hostapd -f"
    echo "- Check service status: sudo systemctl status hostapd dnsmasq"
    echo
    echo "To stop the hotspot:"
    echo "sudo systemctl stop hostapd dnsmasq"
    echo
    echo "To restart the hotspot:"
    echo "sudo systemctl restart hostapd dnsmasq"
    echo
}

# Function to cleanup on error
cleanup() {
    print_error "Setup failed. Cleaning up..."
    systemctl stop hostapd dnsmasq 2>/dev/null || true
    systemctl disable hostapd dnsmasq 2>/dev/null || true
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -s, --ssid SSID           Set WiFi network name (default: MyHotspot)"
    echo "  -p, --password PASSWORD   Set WiFi password (default: MySecurePassword123)"
    echo "  -i, --interface IFACE     Set WiFi interface (default: wlan0)"
    echo "  -c, --channel CHANNEL     Set WiFi channel (default: 7)"
    echo "  -h, --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0                                    # Use default settings"
    echo "  $0 -s MyNetwork -p MyPass123         # Custom SSID and password"
    echo "  $0 --ssid Office --password Secure123 # Long option names"
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--ssid)
                SSID="$2"
                shift 2
                ;;
            -p|--password)
                PASSWORD="$2"
                shift 2
                ;;
            -i|--interface)
                INTERFACE="$2"
                shift 2
                ;;
            -c|--channel)
                CHANNEL="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    print_header "Raspberry Pi WiFi Hotspot Setup"
    print_header "================================"
    echo
    
    # Parse command line arguments
    parse_args "$@"
    
    # Set trap for cleanup
    trap cleanup ERR
    
    # Run setup steps
    check_root
    check_requirements
    update_system
    install_packages
    backup_configs
    configure_network
    configure_hostapd
    configure_dnsmasq
    enable_ip_forwarding
    configure_nat
    start_services
    verify_setup
    display_info
    
    print_status "Setup completed successfully!"
}

# Run main function with all arguments
main "$@"
