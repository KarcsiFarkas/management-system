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
    # The application factory function
    app = Flask(__name__, instance_relative_config=True)

    # Correctly set template and static folder paths relative to the package
    app.template_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'templates')
    app.static_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'static')

    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'a_very_secret_key_change_this_in_production')
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(app.instance_path, DB_NAME)}'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)
    bcrypt.init_app(app)
    login_manager.init_app(app)
    login_manager.login_view = 'auth.login'

    from .models import User

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    # Import and register blueprints
    from .auth import auth as auth_blueprint
    from .views import views as views_blueprint
    from .admin_views import admin_bp as admin_blueprint

    app.register_blueprint(auth_blueprint, url_prefix='/')
    app.register_blueprint(views_blueprint, url_prefix='/')
    app.register_blueprint(admin_blueprint)

    with app.app_context():
        db.create_all()

        # Create default 'admin' user if it doesn't exist
        if not User.query.filter_by(username='admin').first():
            hashed_password = bcrypt.generate_password_hash('admin').decode('utf-8')
            admin_user = User(username='admin', email='admin@example.com', password=hashed_password, is_admin=True)
            db.session.add(admin_user)
            db.session.commit()

    return app