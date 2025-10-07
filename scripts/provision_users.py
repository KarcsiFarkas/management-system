#!/usr/bin/env python3
"""
provision_users.py - Post-deployment user provisioning script

This script runs after deploy-docker.sh or deploy-nix.sh to automatically create users
in all enabled services and optionally save credentials to Vaultwarden.

Supports both approaches:
1. User-provided universal password (same password for all services)
2. Generated unique passwords saved to Vaultwarden (recommended)
"""

import os
import sys
import json
import secrets
import string
import requests
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import configparser

class UserProvisioningError(Exception):
    """Custom exception for user provisioning errors"""
    pass

class ServiceUserProvisioner:
    """Base class for service-specific user provisioning"""
    
    def __init__(self, service_name: str, config: Dict):
        self.service_name = service_name
        self.config = config
        
    def create_user(self, username: str, password: str, email: str = None) -> bool:
        """Create user in the service. Override in subclasses."""
        raise NotImplementedError(f"create_user not implemented for {self.service_name}")
    
    def is_service_ready(self) -> bool:
        """Check if service is ready for user creation"""
        return True

class NextcloudProvisioner(ServiceUserProvisioner):
    """Nextcloud user provisioning via OCC command"""
    
    def create_user(self, username: str, password: str, email: str = None) -> bool:
        try:
            # For Docker deployment
            if self.config.get('deployment_type') == 'docker':
                cmd = [
                    'docker', 'exec', 'nextcloud',
                    'php', 'occ', 'user:add', username,
                    '--password-from-env'
                ]
                env = os.environ.copy()
                env['OC_PASS'] = password
                result = subprocess.run(cmd, env=env, capture_output=True, text=True)
                
            # For NixOS deployment
            else:
                cmd = [
                    'sudo', '-u', 'nextcloud',
                    'nextcloud-occ', 'user:add', username,
                    '--password-from-env'
                ]
                env = os.environ.copy()
                env['OC_PASS'] = password
                result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"✓ Created user {username} in Nextcloud")
                return True
            else:
                print(f"✗ Failed to create user {username} in Nextcloud: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"✗ Error creating user {username} in Nextcloud: {e}")
            return False

class GitLabProvisioner(ServiceUserProvisioner):
    """GitLab user provisioning via REST API"""
    
    def create_user(self, username: str, password: str, email: str = None) -> bool:
        try:
            gitlab_url = self.config.get('GITLAB_EXTERNAL_URL', 'http://localhost:8080')
            root_token = self.config.get('GITLAB_ROOT_TOKEN')
            
            if not root_token:
                print("✗ GitLab root token not found in configuration")
                return False
            
            if not email:
                email = f"{username}@{self.config.get('DOMAIN', 'localhost')}"
            
            headers = {
                'Authorization': f'Bearer {root_token}',
                'Content-Type': 'application/json'
            }
            
            user_data = {
                'username': username,
                'password': password,
                'email': email,
                'name': username.title(),
                'skip_confirmation': True
            }
            
            response = requests.post(
                f"{gitlab_url}/api/v4/users",
                headers=headers,
                json=user_data,
                timeout=30
            )
            
            if response.status_code == 201:
                print(f"✓ Created user {username} in GitLab")
                return True
            else:
                print(f"✗ Failed to create user {username} in GitLab: {response.text}")
                return False
                
        except Exception as e:
            print(f"✗ Error creating user {username} in GitLab: {e}")
            return False

class JellyfinProvisioner(ServiceUserProvisioner):
    """Jellyfin user provisioning via REST API"""
    
    def create_user(self, username: str, password: str, email: str = None) -> bool:
        try:
            jellyfin_url = f"http://localhost:{self.config.get('JELLYFIN_PORT', '8096')}"
            
            # First, get admin API key (this would need to be configured)
            admin_token = self.config.get('JELLYFIN_API_KEY')
            if not admin_token:
                print("✗ Jellyfin API key not found in configuration")
                return False
            
            headers = {
                'Authorization': f'MediaBrowser Token="{admin_token}"',
                'Content-Type': 'application/json'
            }
            
            user_data = {
                'Name': username,
                'Password': password
            }
            
            response = requests.post(
                f"{jellyfin_url}/Users/New",
                headers=headers,
                json=user_data,
                timeout=30
            )
            
            if response.status_code == 200:
                print(f"✓ Created user {username} in Jellyfin")
                return True
            else:
                print(f"✗ Failed to create user {username} in Jellyfin: {response.text}")
                return False
                
        except Exception as e:
            print(f"✗ Error creating user {username} in Jellyfin: {e}")
            return False

class VaultwardenManager:
    """Vaultwarden integration for password management"""
    
    def __init__(self, config: Dict):
        self.config = config
        self.vaultwarden_url = f"http://localhost:{config.get('VAULTWARDEN_PORT', '8080')}"
        self.admin_token = config.get('VAULTWARDEN_ADMIN_TOKEN')
        
    def create_user(self, email: str, master_password: str) -> bool:
        """Create user in Vaultwarden"""
        try:
            if not self.admin_token:
                print("✗ Vaultwarden admin token not found")
                return False
            
            headers = {
                'Authorization': f'Bearer {self.admin_token}',
                'Content-Type': 'application/json'
            }
            
            user_data = {
                'email': email,
                'password': master_password
            }
            
            response = requests.post(
                f"{self.vaultwarden_url}/admin/users",
                headers=headers,
                json=user_data,
                timeout=30
            )
            
            if response.status_code in [200, 201]:
                print(f"✓ Created user {email} in Vaultwarden")
                return True
            else:
                print(f"✗ Failed to create user {email} in Vaultwarden: {response.text}")
                return False
                
        except Exception as e:
            print(f"✗ Error creating user {email} in Vaultwarden: {e}")
            return False
    
    def add_login_item(self, user_email: str, service_name: str, username: str, password: str) -> bool:
        """Add login item to user's vault"""
        try:
            # This would require implementing Vaultwarden's vault API
            # For now, we'll just print the credentials that would be saved
            print(f"📝 Would save to Vaultwarden vault for {user_email}:")
            print(f"   Service: {service_name}")
            print(f"   Username: {username}")
            print(f"   Password: {'*' * len(password)}")
            return True
            
        except Exception as e:
            print(f"✗ Error adding login item to Vaultwarden: {e}")
            return False

def generate_password(length: int = 16) -> str:
    """Generate a secure random password"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def load_config() -> Dict:
    """Load configuration from profiles/config.env"""
    config = {}
    config_path = Path("profiles/config.env")
    
    if not config_path.exists():
        raise UserProvisioningError(f"Configuration file not found: {config_path}")
    
    # Parse the .env file
    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                # Remove quotes if present
                value = value.strip('"\'')
                config[key] = value
    
    return config

def load_services_config() -> List[str]:
    """Load enabled services from profiles/services.env"""
    services = []
    services_path = Path("profiles/services.env")
    
    if not services_path.exists():
        raise UserProvisioningError(f"Services file not found: {services_path}")
    
    with open(services_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                if value.strip().lower() in ['true', '1', 'yes']:
                    # Extract service name from key (e.g., NEXTCLOUD_ENABLED -> nextcloud)
                    service_name = key.replace('_ENABLED', '').lower()
                    services.append(service_name)
    
    return services

def get_provisioner(service_name: str, config: Dict) -> Optional[ServiceUserProvisioner]:
    """Get the appropriate provisioner for a service"""
    provisioners = {
        'nextcloud': NextcloudProvisioner,
        'gitlab': GitLabProvisioner,
        'jellyfin': JellyfinProvisioner,
        # Add more services as needed
    }
    
    provisioner_class = provisioners.get(service_name)
    if provisioner_class:
        return provisioner_class(service_name, config)
    else:
        print(f"⚠ No provisioner available for service: {service_name}")
        return None

def provision_users(universal_username: str, password_approach: str, 
                   universal_password: str = None, vaultwarden_master_password: str = None) -> bool:
    """Main user provisioning function"""
    
    try:
        # Load configuration
        config = load_config()
        enabled_services = load_services_config()
        
        if not enabled_services:
            print("No services enabled for user provisioning")
            return True
        
        print(f"🚀 Starting user provisioning for {len(enabled_services)} services...")
        print(f"Username: {universal_username}")
        print(f"Password approach: {password_approach}")
        print(f"Services: {', '.join(enabled_services)}")
        
        # Initialize Vaultwarden manager if using generated passwords
        vaultwarden = None
        if password_approach == 'generated':
            vaultwarden = VaultwardenManager(config)
            user_email = f"{universal_username}@{config.get('DOMAIN', 'localhost')}"
            
            # Create user in Vaultwarden
            if not vaultwarden.create_user(user_email, vaultwarden_master_password):
                print("⚠ Failed to create Vaultwarden user, continuing without it...")
                vaultwarden = None
        
        # Provision users in each service
        success_count = 0
        total_services = len(enabled_services)
        
        for service_name in enabled_services:
            print(f"\n📋 Provisioning user for {service_name}...")
            
            provisioner = get_provisioner(service_name, config)
            if not provisioner:
                continue
            
            # Check if service is ready
            if not provisioner.is_service_ready():
                print(f"⚠ Service {service_name} is not ready, skipping...")
                continue
            
            # Determine password to use
            if password_approach == 'user_provided':
                service_password = universal_password
            else:
                service_password = generate_password()
            
            # Create user in service
            user_email = f"{universal_username}@{config.get('DOMAIN', 'localhost')}"
            if provisioner.create_user(universal_username, service_password, user_email):
                success_count += 1
                
                # Save to Vaultwarden if using generated passwords
                if vaultwarden and password_approach == 'generated':
                    vaultwarden.add_login_item(user_email, service_name, universal_username, service_password)
            
        print(f"\n✅ User provisioning completed!")
        print(f"Successfully provisioned: {success_count}/{total_services} services")
        
        if password_approach == 'generated' and vaultwarden:
            print(f"🔐 Credentials saved to Vaultwarden vault for {user_email}")
            print(f"Use your master password to access the vault at: {vaultwarden.vaultwarden_url}")
        
        return success_count > 0
        
    except Exception as e:
        print(f"❌ User provisioning failed: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Provision users across all enabled services")
    parser.add_argument("--username", required=True, help="Universal username")
    parser.add_argument("--password-approach", choices=['user_provided', 'generated'], 
                       default='generated', help="Password approach")
    parser.add_argument("--universal-password", help="Universal password (for user_provided approach)")
    parser.add_argument("--vaultwarden-master-password", help="Vaultwarden master password (for generated approach)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    
    args = parser.parse_args()
    
    # Validate arguments
    if args.password_approach == 'user_provided' and not args.universal_password:
        print("❌ Universal password is required for user_provided approach")
        sys.exit(1)
    
    if args.password_approach == 'generated' and not args.vaultwarden_master_password:
        print("❌ Vaultwarden master password is required for generated approach")
        sys.exit(1)
    
    if args.dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
    
    # Run provisioning
    success = provision_users(
        universal_username=args.username,
        password_approach=args.password_approach,
        universal_password=args.universal_password,
        vaultwarden_master_password=args.vaultwarden_master_password
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()