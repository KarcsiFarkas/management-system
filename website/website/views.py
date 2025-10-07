from flask import Blueprint, render_template, request, flash, redirect, url_for, session
from flask_login import login_user, logout_user, login_required, current_user
import json
import os
from .models import User
from . import db, profile_manager

views = Blueprint('views', __name__)

SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), '..', 'services.json')


def load_services_config():
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        return json.load(f)


@views.route('/')
def index():
    """
    The main landing page, which is the public admin dashboard.
    It automatically logs in the 'admin' user.
    If a regular user is already logged in, it saves their session to revert later.
    """
    if current_user.is_authenticated and not current_user.is_admin:
        session['previous_user_id'] = current_user.get_id()
        logout_user()

    if not current_user.is_authenticated or not current_user.is_admin:
        admin_user = User.query.filter_by(is_admin=True, username='admin').first()
        if admin_user:
            login_user(admin_user, remember=True)

    try:
        all_branches = profile_manager.get_all_branches()
        all_users = User.query.filter_by(is_admin=False).all()
        return render_template('admin_dashboard.html', branches=all_branches, users=all_users)
    except Exception as e:
        flash(f"Error loading profiles: {e}", "error")
        return render_template('admin_dashboard.html', branches=[], users=[])


@views.route('/dashboard')
@login_required
def dashboard():
    """
    Handles the user-specific dashboard.
    Also handles "exiting" the admin view to return to the original user.
    """
    if 'previous_user_id' in session:
        logout_user()  # Log out the admin
        original_user_id = session.pop('previous_user_id', None)
        original_user = User.query.get(original_user_id)
        if original_user:
            login_user(original_user, remember=True)
            # Now current_user is the original user, proceed to their dashboard
        else:
            return redirect(url_for('auth.login'))  # Fallback

    # If the admin user tries to access this page directly, redirect them to the admin index
    if current_user.is_admin:
        return redirect(url_for('views.index'))

    # Otherwise, show the regular user's dashboard
    user_configs = profile_manager.get_user_configs(current_user.username)
    return render_template('dashboard.html', configs=user_configs)


@views.route('/impersonate/<int:user_id>')
@login_required
def impersonate(user_id):
    if not current_user.is_admin:
        flash("You do not have permission to perform this action.", "error")
        return redirect(url_for('views.dashboard'))

    user_to_impersonate = User.query.get(user_id)
    if not user_to_impersonate:
        flash("User not found.", "error")
        return redirect(url_for('views.index'))

    session['admin_user_id'] = current_user.get_id()
    logout_user()
    login_user(user_to_impersonate, remember=True)
    flash(f"You are now viewing the dashboard as {user_to_impersonate.username}.", "success")
    return redirect(url_for('views.dashboard'))


@views.route('/discover')
def discover():
    config = load_services_config()
    return render_template('discover.html', config=config)


@views.route('/update-settings', methods=['POST'])
@login_required
def update_settings():
    current_user.global_domain = request.form.get('global_domain')
    current_user.global_timezone = request.form.get('global_timezone')
    current_user.universal_username = request.form.get('universal_username')
    current_user.password_mode = request.form.get('password_mode')

    if current_user.password_mode == 'custom':
        current_user.universal_password_custom = request.form.get('universal_password_custom')
    else:
        current_user.universal_password_custom = None

    db.session.commit()
    flash('Global settings have been updated!', 'success')
    return redirect(url_for('views.dashboard'))


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

        error = profile_manager.create_profile(form_data, current_user)
        if error:
            flash(error, 'error')
        else:
            flash(f"Profile '{config_name}' created successfully!", 'success')
            return redirect(url_for('views.index' if current_user.is_admin else 'views.dashboard'))

    return render_template('form.html', config=config, profile_data=None)


@views.route('/my-configs/edit/<config_name>', methods=['GET', 'POST'])
@login_required
def user_edit_config(config_name):
    if current_user.is_admin:
        return redirect(url_for('views.index'))

    config = load_services_config()
    full_branch_name = f"{current_user.username}-{config_name}"

    if request.method == 'POST':
        form_data = request.form.to_dict()
        error = profile_manager.update_profile(form_data, full_branch_name, current_user)
        if error:
            flash(error, 'error')
        else:
            flash(f"Profile '{config_name}' updated successfully!", 'success')
            return redirect(url_for('views.dashboard'))

    profile_data, error = profile_manager.load_profile(full_branch_name)
    if error:
        flash(error, 'error')
        return redirect(url_for('views.dashboard'))

    if profile_data:
        profile_data['config_name'] = config_name

    return render_template('form.html', config=config, profile_data=profile_data)


@views.route('/edit/<path:branch_name>', methods=['GET', 'POST'])
@login_required
def edit_config(branch_name):
    if not current_user.is_admin:
        flash("You do not have permission to access this page.", "error")
        return redirect(url_for('views.dashboard'))

    config = load_services_config()

    if request.method == 'POST':
        form_data = request.form.to_dict()
        username_from_branch = branch_name.split('-')[0] if '-' in branch_name else 'admin'

        user_object = User.query.filter_by(username=username_from_branch).first()
        if not user_object:
            flash(f"Cannot save, user '{username_from_branch}' does not exist.", "error")
            return redirect(url_for('views.index'))

        error = profile_manager.update_profile(form_data, branch_name, user_object)
        if error:
            flash(error, 'error')
        else:
            flash(f"Profile '{branch_name}' updated successfully!", 'success')
            return redirect(url_for('views.index'))

    profile_data, error = profile_manager.load_profile(branch_name)
    if error:
        flash(error, 'error')
        return redirect(url_for('views.index'))

    if profile_data:
        profile_data['config_name'] = branch_name

    return render_template('form.html', config=config, profile_data=profile_data)