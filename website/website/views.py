from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
import json
import os
from . import profile_manager, db
from .models import User

views = Blueprint('views', __name__)

SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), '..', 'services.json')


def load_services_config():
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        return json.load(f)


@views.route('/')
@login_required
def index():
    """Redirects to the correct dashboard based on user role."""
    if current_user.is_admin:
        return redirect(url_for('admin.index'))
    else:
        return redirect(url_for('views.dashboard'))


@views.route('/dashboard')
@login_required
def dashboard():
    """User-specific dashboard."""
    if current_user.is_admin:
        return redirect(url_for('admin.index'))

    # --- CHANGE: Removed the error flashing logic ---
    # It's normal for a new user to not have a profile. We will handle this
    # gracefully in the template instead of showing an error.
    profile_data, _ = profile_manager.load_tenant_profile(current_user.username)

    return render_template('dashboard.html', profile=profile_data)


@views.route('/discover')
def discover():
    """Shows a read-only view of all available services."""
    config = load_services_config()
    return render_template('discover.html', config=config)


@views.route('/profile', methods=['GET'])
@login_required
def profile():
    """Displays the profile creation/editing form."""
    if current_user.is_admin:
        return redirect(url_for('admin.index'))

    config = load_services_config()

    # --- CHANGE: Removed the error flashing logic ---
    # If the profile is not found, we simply pass `None` to the template,
    # which will correctly render a blank form for creation.
    profile_data, _ = profile_manager.load_tenant_profile(current_user.username)

    return render_template('form.html', config=config, profile_data=profile_data)


@views.route('/save', methods=['POST'])
@login_required
def save_profile():
    """Handles the form submission for a user's own profile."""
    if current_user.is_admin:
        flash("Admins should save profiles through the admin panel.", "error")
        return redirect(url_for('admin.index'))

    form_data = request.form.to_dict()
    error = profile_manager.create_or_update_tenant_profile(form_data, current_user)
    if error:
        flash(error, 'error')
    else:
        flash('Profile saved successfully!', 'success')

    return redirect(url_for('views.dashboard'))


@views.route('/update-settings', methods=['POST'])
@login_required
def update_settings():
    """Handles the form submission from the user dashboard for global settings."""
    # This route is now part of the main profile form, but we keep it
    # in case you want to separate it again in the future. The logic is now
    # handled by create_or_update_tenant_profile.
    # For now, we just redirect.
    return redirect(url_for('views.dashboard'))