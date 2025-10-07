import os
import git
import json

# Use an absolute path to the project root to make repo discovery more robust
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
PROFILES_REPO_PATH = os.path.join(PROJECT_ROOT, 'profiles')
SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'services.json')


def get_repo():
    """Initializes and returns the Repo object."""
    if not os.path.isdir(PROFILES_REPO_PATH):
        raise FileNotFoundError(
            f"Profiles directory not found at {PROFILES_REPO_PATH}. Please ensure the 'profiles' submodule exists.")
    return git.Repo(PROFILES_REPO_PATH)


def get_existing_users():
    """Returns a list of existing user branches."""
    repo = get_repo()
    # Ensure we don't list the 'main' or 'master' branch as a user
    return [head.name for head in repo.heads if head.name not in ['main', 'master']]


def load_profile(username):
    """Checks out a user's branch and parses their config file."""
    repo = get_repo()
    if username not in [head.name for head in repo.heads]:
        return None, "User profile not found."

    # Stash any local changes to avoid conflicts, then checkout the user branch
    if repo.is_dirty(untracked_files=True):
        repo.git.stash('save', '--include-untracked')

    repo.heads[username].checkout()

    config_data = {'username': username}
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')

    if not os.path.exists(services_env_path) or not os.path.exists(config_env_path):
        repo.heads.main.checkout()  # Return to main branch
        return None, "The profile for this user is incomplete. 'services.env' or 'config.env' is missing."

    config_data['services'] = {}

    # Parse services.env for enabled services
    with open(services_env_path, 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                config_data[key] = value.strip('"\'')  # Strip quotes
                if key.startswith('SERVICE_') and key.endswith('_ENABLED'):
                    service_id = key.replace('SERVICE_', '').replace('_ENABLED', '').lower()
                    if value.lower().strip('"\'') == 'true':
                        config_data['services'][service_id] = 'on'

    # Parse config.env for configuration values
    with open(config_env_path, 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                config_data[key] = value.strip('"\'')  # Strip quotes

    config_data['deployment_type'] = config_data.get('DEPLOYMENT_TYPE', 'docker')

    # Return to main branch to leave repo in a clean state
    repo.heads.main.checkout()
    return config_data, None


def create_or_update_profile(form_data):
    """Creates or updates a user profile branch with the generated config."""
    username = form_data.get('username')
    deployment_type = form_data.get('deployment_type')
    if not username or not deployment_type:
        return "Username and deployment type are required."

    repo = get_repo()

    # Ensure main/master branch is clean before switching
    if repo.is_dirty(untracked_files=True):
        repo.git.stash('save', '--include-untracked')

    main_branch = 'main' if 'main' in [h.name for h in repo.heads] else 'master'
    repo.heads[main_branch].checkout()

    # Create new branch from main if it doesn't exist
    if username not in [head.name for head in repo.heads]:
        repo.create_head(username, main_branch)

    # Checkout the user's branch
    repo.heads[username].checkout()

    # Load services definition
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        services_def = json.load(f)

    # Generate services.env file
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    services_content = [
        "# Service Activation Configuration",
        f"DEPLOYMENT_TYPE={deployment_type}",
        ""
    ]
    for service in services_def['services']:
        service_id = service['id']
        is_enabled = f'service_{service_id}' in form_data
        services_content.append(f"SERVICE_{service_id.upper()}_ENABLED={'true' if is_enabled else 'false'}")

    with open(services_env_path, 'w') as f:
        f.write('\n'.join(services_content))
    repo.index.add([services_env_path])

    # Generate config.env file
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')
    config_content = ["# Service Configuration Parameters", ""]

    # Add user provisioning configuration
    universal_username = form_data.get('universal_username', '')
    password_approach = form_data.get('password_approach', 'generated')
    universal_password = form_data.get('universal_password', '')
    vaultwarden_master_password = form_data.get('vaultwarden_master_password', '')
    auto_provision_users = form_data.get('auto_provision_users', 'false')

    if universal_username or password_approach != 'generated':
        config_content.extend([
            "# --- User Provisioning Configuration ---",
            f"UNIVERSAL_USERNAME=\"{universal_username}\"",
            f"PASSWORD_APPROACH=\"{password_approach}\"",
            f"AUTO_PROVISION_USERS=\"{auto_provision_users}\"",
            ""
        ])

        # Only store universal password if using user_provided approach
        if password_approach == 'user_provided' and universal_password:
            config_content.append(f"UNIVERSAL_PASSWORD=\"{universal_password}\"")

        # Store Vaultwarden master password if using generated approach
        if password_approach == 'generated' and vaultwarden_master_password:
            config_content.append(f"VAULTWARDEN_MASTER_PASSWORD=\"{vaultwarden_master_password}\"")

        config_content.append("")

    # Add global fields
    global_fields = services_def['global_fields'].get(deployment_type, [])
    for field in global_fields:
        value = form_data.get(field['name'], field.get('default', ''))
        config_content.append(f"{field['name']}=\"{value}\"")

    # Add service-specific fields for enabled services
    for service in services_def['services']:
        service_id = service['id']
        if f'service_{service_id}' in form_data:
            config_content.append(f"\n# --- {service['name']} Configuration ---")
            service_fields = service.get(f'{deployment_type}_fields', [])
            for field in service_fields:
                value = form_data.get(field['name'], field.get('default', ''))
                if field.get('type') == 'checkbox':
                    value = 'true' if field['name'] in form_data else 'false'
                config_content.append(f"{field['name']}=\"{value}\"")

    with open(config_env_path, 'w') as f:
        f.write('\n'.join(config_content))
    repo.index.add([config_env_path])

    # Commit changes if there are any
    if repo.is_dirty(untracked_files=True):
        repo.index.commit(f"Update configuration for profile: {username}")

    # Return to main branch to leave repo in a clean state
    repo.heads[main_branch].checkout()
    return None
