from flask import Blueprint, render_template, request, flash, redirect, url_for
import os
import yaml
from . import profile_manager, db
from .models import User
from flask_login import login_required, current_user
from functools import wraps

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_admin:
            flash("Admin access is required for this page.", "error")
            return redirect(url_for('views.dashboard'))
        return f(*args, **kwargs)
    return decorated_function

admin_bp = Blueprint('admin', __name__, url_prefix='/admin')

CONFIG_REPO_PATH = profile_manager.CONFIG_REPO_PATH

def get_available_infrastructures():
    infra_dir = os.path.join(CONFIG_REPO_PATH, 'infrastructure')
    if not os.path.isdir(infra_dir): return []
    return [f.replace('.yml', '') for f in os.listdir(infra_dir) if f.endswith('.yml')]

def get_tenant_configs():
    all_tenants = []
    for tenant_name in profile_manager.get_all_tenants():
        profile_data, _ = profile_manager.load_tenant_profile(tenant_name)
        all_tenants.append({
            'name': tenant_name,
            'target': profile_data.get('general', {}).get('deployment_target', 'Not Set') if profile_data else 'Not Found',
            'runtime': profile_data.get('general', {}).get('deployment_runtime', 'Not Set') if profile_data else 'Not Found'
        })
    return sorted(all_tenants, key=lambda x: x['name'])

@admin_bp.route('/')
@login_required
@admin_required
def index():
    tenants = get_tenant_configs()
    infrastructures = get_available_infrastructures()
    users = User.query.filter_by(is_admin=False).all()
    return render_template('admin/index.html', tenants=tenants, infrastructures=infrastructures, users=users)

@admin_bp.route('/link', methods=['POST'])
@login_required
@admin_required
def link_target():
    tenant_name = request.form.get('tenant_name')
    infra_target = request.form.get('infra_target')
    repo = profile_manager.get_repo()
    general_path = os.path.join(CONFIG_REPO_PATH, 'tenants', tenant_name, 'general.conf.yml')

    if not os.path.isfile(general_path):
        flash(f"General config for tenant '{tenant_name}' not found!", 'error')
        return redirect(url_for('admin.index'))

    with open(general_path, 'r') as f: data = yaml.safe_load(f) or {}
    data['deployment_target'] = infra_target
    with open(general_path, 'w') as f: yaml.dump(data, f, sort_keys=False)

    repo.index.add([general_path])
    repo.index.commit(f"chore(admin): Link tenant {tenant_name} to {infra_target}")
    if repo.remotes: repo.remotes.origin.push()
    flash(f"Successfully linked '{tenant_name}' to '{infra_target}'.", 'success')
    return redirect(url_for('admin.index'))

@admin_bp.route('/edit/<tenant_name>')
@login_required
@admin_required
def edit_tenant(tenant_name):
    config = profile_manager.load_services_config()
    profile_data, error = profile_manager.load_tenant_profile(tenant_name)
    if error:
        flash(error, 'error')
        return redirect(url_for('admin.index'))
    return render_template('form.html', config=config, profile_data=profile_data, tenant_name_override=tenant_name)

@admin_bp.route('/save', methods=['POST'])
@login_required
@admin_required
def save_tenant_profile():
    form_data = request.form.to_dict()
    tenant_name = form_data.get('tenant_name_override')
    if not tenant_name:
        flash("Tenant name not specified.", "error")
        return redirect(url_for('admin.index'))

    user_object = User.query.filter_by(username=tenant_name).first()
    if not user_object:
        flash(f"Cannot save, user '{tenant_name}' not in database.", "error")
        return redirect(url_for('admin.index'))

    error = profile_manager.create_or_update_tenant_profile(form_data, user_object)
    if error: flash(error, 'error')
    else: flash(f"Profile for '{tenant_name}' saved successfully!", 'success')
    return redirect(url_for('admin.index'))
