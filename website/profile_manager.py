import os
import git
import json

PROFILES_REPO_PATH = os.path.join(os.path.dirname(__file__), '..', 'profiles')
SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'services.json')

def get_repo():
    """Initializes and returns the Repo object."""
    if not os.path.isdir(PROFILES_REPO_PATH):
        raise FileNotFoundError("Profiles directory not found. Please run from project root.")
    return git.Repo(PROFILES_REPO_PATH)

def get_existing_users():
    """Returns a list of existing user branches."""
    repo = get_repo()
    return [head.name for head in repo.heads if head.name != 'main']

def load_profile(username):
    """Checks out a user's branch and parses their config file."""
    repo = get_repo()
    if username not in [head.name for head in repo.heads]:
        return None, "User profile not found."

    # Stash any local changes and checkout the user branch
    repo.git.stash()
    repo.heads[username].checkout()

    config_data = {'username': username}

    # Try to read new format: services.env and config.env
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')

    if os.path.exists(services_env_path) and os.path.exists(config_env_path):
        config_data['services'] = {}

        # Parse services.env for enabled services
        with open(services_env_path, 'r') as f:
            for line in f:
                if '=' in line and not line.strip().startswith('#'):
                    key, value = line.strip().split('=', 1)
                    config_data[key] = value
                    if key.startswith('SERVICE_') and key.endswith('_ENABLED'):
                        service_id = key.replace('SERVICE_', '').replace('_ENABLED', '').lower()
                        if value.lower() == 'true':
                            config_data['services'][service_id] = 'on'

        # Parse config.env for configuration values
        with open(config_env_path, 'r') as f:
            for line in f:
                if '=' in line and not line.strip().startswith('#'):
                    key, value = line.strip().split('=', 1)
                    config_data[key] = value

        # Determine deployment type from config
        config_data['deployment_type'] = config_data.get('DEPLOYMENT_TYPE', 'docker')
        return config_data, None

    # Fallback: Try to read legacy docker config
    docker_env_path = os.path.join(PROFILES_REPO_PATH, 'docker.env')
    if os.path.exists(docker_env_path):
        config_data['deployment_type'] = 'docker'
        config_data['services'] = {}
        with open(docker_env_path, 'r') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    config_data[key] = value
                    if key.startswith('ENABLE_'):
                        service_id = key.replace('ENABLE_', '').lower()
                        if value.lower() == 'true':
                            config_data['services'][service_id] = 'on'
        return config_data, None

    # Fallback: Try to read legacy nix config
    nix_profile_path = os.path.join(PROFILES_REPO_PATH, 'nix-profile.nix')
    if os.path.exists(nix_profile_path):
        config_data['deployment_type'] = 'nix'
        config_data['services'] = {}
        with open(nix_profile_path, 'r') as f:
            content = f.read()
            # Simple parsing for enabled services
            for line in content.splitlines():
                line = line.strip()
                if line.startswith('services.') and line.endswith('.enable = true;'):
                    service_id = line.split('.')[1]
                    config_data['services'][service_id] = 'on'
                elif '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip().strip(';').strip('"')
                    config_data[key] = value
        return config_data, None

    return None, "No valid config file found in profile."

def create_or_update_profile(form_data):
    """Creates or updates a user profile branch with the generated config."""
    username = form_data.get('username')
    deployment_type = form_data.get('deployment_type')
    if not username or not deployment_type:
        return "Username and deployment type are required."

    repo = get_repo()

    # Create new branch if it doesn't exist
    if username not in [head.name for head in repo.heads]:
        repo.create_head(username)

    # Checkout the user's branch
    repo.git.stash()
    repo.heads[username].checkout()

    # Load services definition
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        services_def = json.load(f)

    # Generate services.env file (service activation toggles)
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    services_content = [
        "# Service Activation Configuration",
        "# Enable or disable services by setting the value to 'true' or 'false'",
        "",
        "# Deployment Type",
        f"DEPLOYMENT_TYPE={deployment_type}",
        "",
        "# Service Toggles"
    ]

    for service in services_def['services']:
        service_id = service['id']
        is_enabled = f'service_{service_id}' in form_data
        services_content.append(f"SERVICE_{service_id.upper()}_ENABLED={'true' if is_enabled else 'false'}")

    with open(services_env_path, 'w') as f:
        f.write('\n'.join(services_content))
    repo.index.add([services_env_path])

    # Generate config.env file (service-specific parameters)
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')
    config_content = [
        "# Service Configuration Parameters",
        "# This file contains all user-specific variables for configuring enabled services",
        "",
        "# Global Configuration"
    ]

    # Add global fields based on deployment type
    global_fields = services_def['global_fields'].get(deployment_type, [])
    for field in global_fields:
        value = form_data.get(field['name'], field.get('default', ''))
        config_content.append(f"{field['name']}={value}")

    # Add service-specific configuration for enabled services
    for service in services_def['services']:
        service_id = service['id']
        if f'service_{service_id}' in form_data:
            config_content.extend([
                "",
                f"# {service['name']} Configuration"
            ])

            # Add fields based on deployment type
            service_fields = service.get(f'{deployment_type}_fields', [])
            for field in service_fields:
                value = form_data.get(field['name'], field.get('default', ''))
                # Handle checkbox fields
                if field.get('type') == 'checkbox':
                    value = 'true' if value else 'false'
                config_content.append(f"{field['name']}={value}")

    # Add common integration variables
    config_content.extend([
        "",
        "# Integration Configuration",
        f"MEDIA_ROOT=/srv/media",
        f"DOWNLOADS_ROOT=/srv/downloads",
        f"POSTGRES_USER=paas_user",
        f"POSTGRES_PASSWORD=changeme",
        f"MYSQL_ROOT_PASSWORD=changeme",
        f"LDAP_BASE_DN=dc={form_data.get('DOMAIN', 'example.local').replace('.', ',dc=')}",
        f"ADMIN_EMAIL=admin@{form_data.get('DOMAIN', 'example.local')}"
    ])

    with open(config_env_path, 'w') as f:
        f.write('\n'.join(config_content))
    repo.index.add([config_env_path])

    # Clean up legacy files if they exist
    legacy_files = ['docker.env', 'nix-profile.nix']
    for legacy_file in legacy_files:
        legacy_path = os.path.join(PROFILES_REPO_PATH, legacy_file)
        if os.path.exists(legacy_path):
            os.remove(legacy_path)
            try:
                repo.index.remove([legacy_path])
            except:
                pass  # File might not be in git index

    # Commit changes
    repo.index.commit(f"Update configuration for {username} (new format)")

    # Return to main branch to leave repo in a clean state
    repo.heads.main.checkout()
    return None
