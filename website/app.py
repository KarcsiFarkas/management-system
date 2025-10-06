from flask import Flask, render_template, request, redirect, url_for, flash
import json
import os
import profile_manager

app = Flask(__name__)
app.secret_key = 'supersecretkey' # Replace with a real secret key in production

SERVICES_CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'services.json')

def load_services_config():
    with open(SERVICES_CONFIG_PATH, 'r') as f:
        return json.load(f)

@app.route('/')
def index():
    users = profile_manager.get_existing_users()
    return render_template('index.html', users=users)

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
    form_data = request.form.to_dict()
    error = profile_manager.create_or_update_profile(form_data)
    if error:
        flash(error, 'error')
        return redirect(url_for('new_profile')) # Or back to the form with data
    
    flash(f"Profile for '{form_data.get('username')}' saved successfully!", 'success')
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)