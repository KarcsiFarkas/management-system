import os
import git
import json
import yaml

DEFAULT_CONFIG_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'ms-config'))
CONFIG_REPO_PATH = os.environ.get('CONFIG_REPO_PATH', DEFAULT_CONFIG_PATH)
SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), '..', 'services.json')


def get_repo():
    """Initializes and returns the Repo object, ensuring it's on the main branch and up-to-date."""
    if not os.path.isdir(CONFIG_REPO_PATH):
        raise FileNotFoundError(
            f"Configuration repository not found at: {CONFIG_REPO_PATH}. Set the CONFIG_REPO_PATH environment variable.")
    if not os.path.isdir(os.path.join(CONFIG_REPO_PATH, '.git')):
        raise git.InvalidGitRepositoryError(f"The path '{CONFIG_REPO_PATH}' is not a valid Git repository.")

    repo = git.Repo(CONFIG_REPO_PATH)

    if 'main' in repo.heads:
        if repo.head.ref != repo.heads.main:
            repo.heads.main.checkout()
    else:
        raise git.InvalidGitRepositoryError("Default branch 'main' not found in the configuration repository.")

    if repo.remotes:
        origin = repo.remotes.origin
        origin.pull()

    return repo


def get_all_tenants():
    """Returns a list of all tenant directories, ignoring files."""
    tenants_dir = os.path.join(CONFIG_REPO_PATH, 'tenants')
    if not os.path.isdir(tenants_dir):
        os.makedirs(tenants_dir)
        return []
    # This ensures we only list directories, preventing errors with stray files.
    return sorted([d for d in os.listdir(tenants_dir) if os.path.isdir(os.path.join(tenants_dir, d))])


def load_tenant_profile(tenant_name):
    """Loads and merges a tenant's general.conf.yml and selection.yml files."""
    general_path = os.path.join(CONFIG_REPO_PATH, 'tenants', tenant_name, 'general.conf.yml')
    selection_path = os.path.join(CONFIG_REPO_PATH, 'tenants', tenant_name, 'selection.yml')

    if not os.path.isfile(general_path) and not os.path.isfile(selection_path):
        return None, f"No configuration files found for tenant '{tenant_name}'."

    profile_data = {'general': {}, 'services': {}}

    try:
        if os.path.isfile(general_path):
            with open(general_path, 'r') as f:
                profile_data['general'] = yaml.safe_load(f) or {}

        if os.path.isfile(selection_path):
            with open(selection_path, 'r') as f:
                selection_content = yaml.safe_load(f) or {}
                profile_data['services'] = selection_content.get('services', {})

        profile_data['tenant_name'] = tenant_name
        return profile_data, None
    except Exception as e:
        return None, f"Error reading configuration for tenant '{tenant_name}': {e}"


def load_services_config():
    """Loads the services configuration from services.json."""
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        return json.load(f)


def create_or_update_tenant_profile(form_data, user_object):
    """Creates/updates a tenant's general.conf.yml and selection.yml and commits them."""
    tenant_name = form_data.get('tenant_name_override', user_object.username)
    if not tenant_name:
        return "Invalid username for tenant operation."

    repo = get_repo()
    tenant_dir = os.path.join(CONFIG_REPO_PATH, 'tenants', tenant_name)
    os.makedirs(tenant_dir, exist_ok=True)

    general_path = os.path.join(tenant_dir, 'general.conf.yml')
    selection_path = os.path.join(tenant_dir, 'selection.yml')

    # --- 1. Prepare and write general.conf.yml ---
    general_data = {
        'tenant_domain': form_data.get('tenant_domain', user_object.global_domain),
        'deployment_runtime': form_data.get('deployment_runtime', 'docker'),
        'timezone': form_data.get('timezone', user_object.global_timezone),
        'universal_username': form_data.get('universal_username', user_object.username),
        'password_mode': form_data.get('password_mode', 'generate'),
        'deployment_target': None
    }
    if general_data['password_mode'] == 'custom':
        general_data['universal_password_custom'] = form_data.get('universal_password_custom', '')

    if os.path.exists(general_path):
        with open(general_path, 'r') as f:
            existing_data = yaml.safe_load(f)
            if existing_data and 'deployment_target' in existing_data:
                general_data['deployment_target'] = existing_data['deployment_target']

    with open(general_path, 'w') as f:
        yaml.dump(general_data, f, sort_keys=False, indent=2, default_flow_style=False)

    # --- 2. Prepare and write selection.yml ---
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        services_def = json.load(f)

    selection_data = {'services': {}}
    deployment_type = general_data['deployment_runtime']

    for service in services_def['services']:
        service_id = service['id']
        if f'service_{service_id}' in form_data:
            service_config = {'enabled': True, 'options': {}}
            fields_key = f'{deployment_type}_fields'
            for field in service.get(fields_key, []):
                field_name = field['name']
                if field.get('type') == 'checkbox':
                    service_config['options'][field_name] = field_name in form_data
                elif field_name in form_data:
                    service_config['options'][field_name] = form_data.get(field_name)
            selection_data['services'][service_id] = service_config

    with open(selection_path, 'w') as f:
        yaml.dump(selection_data, f, sort_keys=False, indent=2, default_flow_style=False)

    # --- 3. Commit both files atomically ---
    try:
        repo.index.add([general_path, selection_path])
        commit_message = f"feat({tenant_name}): Update tenant configuration via web UI"
        if repo.is_dirty(index=True, working_tree=False, untracked_files=True):
            repo.index.commit(commit_message)
            if repo.remotes:
                origin = repo.remotes.origin
                origin.push()
    except Exception as e:
        return f"Error committing to Git repository: {e}"

    return None
