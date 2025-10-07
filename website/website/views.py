from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
import json
import os
from . import profile_manager  # This import now works because the file is in the same directory

views = Blueprint('views', __name__)

SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), '..', 'services.json')


def load_services_config():
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        return json.load(f)


@views.route('/')
@views.route('/dashboard')
@login_required
def dashboard():
    if current_user.is_admin:
        all_branches = profile_manager.get_all_branches()
        return render_template('admin_dashboard.html', branches=all_branches)
    else:
        user_configs = profile_manager.get_user_configs(current_user.username)
        return render_template('dashboard.html', configs=user_configs)


@views.route('/discover')
def discover():
    config = load_services_config()
    return render_template('discover.html', config=config)


@views.route('/new', methods=['GET', 'POST'])
@login_required
def new_config():
    config = load_services_config()
    if request.method == 'POST':
        form_data = request.form.to_dict()
        config_name = form_data.get('config_name')
        if not config_name:
            flash('Configuration name is required.', 'error')
            return render_template('form.html', config=config, profile_data=None)

        error = profile_manager.create_or_update_profile(form_data, current_user.username)
        if error:
            flash(error, 'error')
        else:
            flash(f"Profile '{config_name}' created successfully!", 'success')
            return redirect(url_for('views.dashboard'))

    return render_template('form.html', config=config, profile_data=None)


@views.route('/edit/<config_name>', methods=['GET', 'POST'])
@login_required
def edit_config(config_name):
    config = load_services_config()
    full_branch_name = f"{current_user.username}-{config_name}"

    # Security Check: Ensure a user cannot edit another user's config unless they are an admin
    if not current_user.is_admin and not full_branch_name.startswith(f"{current_user.username}-"):
        flash("You do not have permission to edit this profile.", "error")
        return redirect(url_for('views.dashboard'))

    if request.method == 'POST':
        form_data = request.form.to_dict()
        error = profile_manager.create_or_update_profile(form_data, current_user.username)
        if error:
            flash(error, 'error')
        else:
            flash(f"Profile '{config_name}' updated successfully!", 'success')
            return redirect(url_for('views.dashboard'))

    profile_data, error = profile_manager.load_profile(full_branch_name)
    if error:
        flash(error, 'error')
        return redirect(url_for('views.dashboard'))

    if profile_data:  # Ensure profile_data is not None
        profile_data['config_name'] = config_name

    return render_template('form.html', config=config, profile_data=profile_data)