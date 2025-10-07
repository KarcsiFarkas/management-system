from flask import Flask, render_template, request, redirect, url_for, flash
import json
import os
import profile_manager
import logging

app = Flask(__name__)
app.secret_key = 'supersecretkey'

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'services.json')


def load_services_config():
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        return json.load(f)


@app.route('/')
def index():
    try:
        users = profile_manager.get_existing_users()
        return render_template('index.html', users=users)
    except Exception as e:
        app.logger.error(f"Failed to get existing users: {e}", exc_info=True)
        flash("Error loading user profiles. Please check the 'profiles' repository configuration.", "error")
        return render_template('index.html', users=[])


@app.route('/discover')
def discover():
    config = load_services_config()
    return render_template('discover.html', config=config)


@app.route('/new')
def new_profile():
    config = load_services_config()
    return render_template('form.html', config=config, profile_data=None)


@app.route('/load', methods=['POST'])
def load_profile_post():
    username = request.form.get('username')
    if not username:
        flash('Please select a user to load.', 'error')
        return redirect(url_for('index'))
    return redirect(url_for('edit_profile', username=username))


@app.route('/edit/<username>')
def edit_profile(username):
    config = load_services_config()
    profile_data, error = profile_manager.load_profile(username)
    if error:
        flash(error, 'error')
        return redirect(url_for('index'))
    return render_template('form.html', config=config, profile_data=profile_data)


@app.route('/generate', methods=['POST'])
def generate():
    app.logger.info("'/generate' route hit, button press registered.")
    form_data = request.form.to_dict()
    app.logger.info(f"Received form data for user: '{form_data.get('username')}'")

    try:
        error = profile_manager.create_or_update_profile(form_data)
        if error:
            app.logger.error(f"Error returned from profile_manager: {error}")
            flash(error, 'error')
            return redirect(url_for('new_profile'))

        username = form_data.get('username')
        flash(f"Profile for '{username}' saved successfully!", 'success')
        app.logger.info(f"Successfully generated/updated profile for '{username}'")
        return redirect(url_for('index'))
    except Exception as e:
        app.logger.error(f"An unhandled exception occurred during profile generation: {e}", exc_info=True)
        flash(f"A critical error occurred: {e}", "error")
        return redirect(url_for('index'))


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)