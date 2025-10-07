import os
import git
import json

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PROFILES_REPO_PATH = os.path.join(PROJECT_ROOT, 'profiles')
SERVICES_CONFIG_PATH = os.path.join(PROJECT_ROOT, 'website', 'services.json')


def get_repo():
    if not os.path.isdir(PROFILES_REPO_PATH):
        raise FileNotFoundError(
            f"Profiles directory not found at {PROFILES_REPO_PATH}. Please ensure the 'profiles' submodule is initialized.")
    return git.Repo(PROFILES_REPO_PATH)


def get_all_branches():
    repo = get_repo()
    return [head.name for head in repo.heads if head.name not in ['main', 'master']]


def get_user_configs(username):
    repo = get_repo()
    prefix = f"{username}-"
    user_branches = [head.name for head in repo.heads if head.name.startswith(prefix)]
    return [branch.replace(prefix, '', 1) for branch in user_branches]


def load_profile(full_branch_name):
    repo = get_repo()
    if full_branch_name not in [head.name for head in repo.heads]:
        return None, "Profile not found."

    main_branch = 'main' if 'main' in [h.name for h in repo.heads] else 'master'

    if repo.is_dirty(untracked_files=True):
        repo.git.stash('save', '--include-untracked')

    repo.heads[full_branch_name].checkout()

    config_data = {}
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')

    if not os.path.exists(services_env_path) or not os.path.exists(config_env_path):
        repo.heads[main_branch].checkout()
        return None, "Profile is incomplete."

    config_data['services'] = {}
    with open(services_env_path, 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                config_data[key] = value.strip('"\'')
                if key.startswith('SERVICE_') and key.endswith('_ENABLED') and value.strip('"\'').lower() == 'true':
                    service_id = key.replace('SERVICE_', '').replace('_ENABLED', '').lower()
                    config_data['services'][service_id] = 'on'

    with open(config_env_path, 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                config_data[key] = value.strip('"\'')

    config_data['deployment_type'] = config_data.get('DEPLOYMENT_TYPE', 'docker')

    repo.heads[main_branch].checkout()
    return config_data, None


def _write_profile_files(form_data, user, repo):
    """A helper function to generate and write the config files."""
    deployment_type = form_data.get('deployment_type')

    with open(SERVICES_CONFIG_PATH, 'r') as f:
        services_def = json.load(f)

    # Generate services.env
    services_content = [f"DEPLOYMENT_TYPE={deployment_type}"]
    for service in services_def['services']:
        service_id = service['id']
        is_enabled = f'service_{service_id}' in form_data
        services_content.append(f"SERVICE_{service_id.upper()}_ENABLED={'true' if is_enabled else 'false'}")

    # Generate config.env
    config_content = [
        f"DOMAIN=\"{user.global_domain}\"",
        f"TIMEZONE=\"{user.global_timezone}\"",
        f"UNIVERSAL_USERNAME=\"{user.universal_username or user.username}\"",
        f"PASSWORD_MODE=\"{user.password_mode}\""
    ]
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

    # Write files
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')
    with open(services_env_path, 'w') as f:
        f.write('\n'.join(services_content))
    with open(config_env_path, 'w') as f:
        f.write('\n'.join(config_content))

    repo.index.add([services_env_path, config_env_path])


def create_profile(form_data, user):
    """Creates a new profile branch."""
    config_name = form_data.get('config_name')
    if not config_name:
        return "Configuration name is required."

    full_branch_name = f"{user.username}-{config_name}"
    if not all(c.isalnum() or c in '-_' for c in full_branch_name):
        return "Names can only contain letters, numbers, hyphens, and underscores."

    repo = get_repo()
    main_branch = 'main' if 'main' in [h.name for h in repo.heads] else 'master'

    if full_branch_name in [h.name for h in repo.heads]:
        return f"A profile with the name '{config_name}' already exists."

    repo.create_head(full_branch_name, main_branch)
    repo.heads[full_branch_name].checkout()

    _write_profile_files(form_data, user, repo)

    repo.index.commit(f"Create profile: {full_branch_name}")
    repo.heads[main_branch].checkout()
    return None


def update_profile(form_data, full_branch_name, user):
    """Updates an existing profile branch."""
    repo = get_repo()
    main_branch = 'main' if 'main' in [h.name for h in repo.heads] else 'master'

    if full_branch_name not in [h.name for h in repo.heads]:
        return "Cannot update a profile that does not exist."

    repo.heads[full_branch_name].checkout()

    _write_profile_files(form_data, user, repo)

    if repo.is_dirty(index=True, working_tree=False):
        repo.index.commit(f"Update configuration for profile: {full_branch_name}")

    repo.heads[main_branch].checkout()
    return None