from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_login import LoginManager
import os

db = SQLAlchemy()
bcrypt = Bcrypt()
login_manager = LoginManager()
DB_NAME = "users.db"


def create_app():
    app = Flask(__name__, instance_relative_config=True)

    # Ensure the instance folder exists
    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    app.config['SECRET_KEY'] = 'a_very_secret_key_change_this'  # Change this to a random string
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(app.instance_path, DB_NAME)}'

    db.init_app(app)
    bcrypt.init_app(app)

    login_manager.init_app(app)
    login_manager.login_view = 'auth.login'  # Redirect to login page if user is not authenticated

    from .models import User

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    # Import and register Blueprints
    from .auth import auth as auth_blueprint
    from .views import views as views_blueprint

    app.register_blueprint(auth_blueprint, url_prefix='/')
    app.register_blueprint(views_blueprint, url_prefix='/')

    with app.app_context():
        db.create_all()
        # Create an admin user if one doesn't exist
        if not User.query.filter_by(username='admin').first():
            hashed_password = bcrypt.generate_password_hash('admin').decode('utf-8')
            admin_user = User(username='admin', email='admin@example.com', password=hashed_password, is_admin=True)
            db.session.add(admin_user)
            db.session.commit()

    return app