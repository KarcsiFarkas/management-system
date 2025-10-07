import os
import git

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
PROFILES_REPO_PATH = os.path.join(PROJECT_ROOT, 'profiles')
SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'services.json')


def get_repo():
    if not os.path.isdir(PROFILES_REPO_PATH):
        raise FileNotFoundError(f"Profiles directory not found at {PROFILES_REPO_PATH}.")
    return git.Repo(PROFILES_REPO_PATH)


def get_all_branches():
    repo = get_repo()
    return [head.name for head in repo.heads if head.name not in ['main', 'master']]


def get_user_configs(username):
    repo = get_repo()
    prefix = f"{username}-"
    user_branches = [head.name for head in repo.heads if head.name.startswith(prefix)]
    # Return just the config name part
    return [branch.replace(prefix, '', 1) for branch in user_branches]


def load_profile(full_branch_name):
    repo = get_repo()
    if full_branch_name not in [head.name for head in repo.heads]:
        return None, "Profile not found."

    repo.git.stash()
    repo.heads[full_branch_name].checkout()

    config_data = {}
    services_env_path = os.path.join(PROFILES_REPO_PATH, 'services.env')
    config_env_path = os.path.join(PROFILES_REPO_PATH, 'config.env')

    if not os.path.exists(services_env_path) or not os.path.exists(config_env_path):
        repo.heads.main.checkout()
        return None, "Profile is incomplete."

    config_data['services'] = {}
    with open(services_env_path, 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                value = value.strip('"\'')
                config_data[key] = value
                if key.startswith('SERVICE_') and key.endswith('_ENABLED') and value.lower() == 'true':
                    service_id = key.replace('SERVICE_', '').replace('_ENABLED', '').lower()
                    config_data['services'][service_id] = 'on'

    with open(config_env_path, 'r') as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                key, value = line.strip().split('=', 1)
                config_data[key] = value.strip('"\'')

    config_data['deployment_type'] = config_data.get('DEPLOYMENT_TYPE', 'docker')
    repo.heads.main.checkout()
    return config_data, None


def create_or_update_profile(form_data, username):
    config_name = form_data.get('config_name')
    deployment_type = form_data.get('deployment_type')
    if not config_name or not deployment_type:
        return "Configuration name and deployment type are required."

    full_branch_name = f"{username}-{config_name}"

    # Simple validation for branch name
    if not all(c.isalnum() or c in '-_' for c in full_branch_name):
        return "Username and Config Name can only contain letters, numbers, hyphens, and underscores."

    repo = get_repo()
    main_branch = 'main' if 'main' in [h.name for h in repo.heads] else 'master'

    if full_branch_name not in [h.name for h in repo.heads]:
        repo.create_head(full_branch_name, main_branch)

    repo.git.stash()
    repo.heads[full_branch_name].checkout()

    # This part of the logic remains largely the same, generating the files
    # ... (generate services.env and config.env content as before) ...
    # (For brevity, this logic is omitted, but it is the same as your current version)

    repo.index.commit(f"Update configuration for {full_branch_name}")
    repo.heads[main_branch].checkout()
    return None