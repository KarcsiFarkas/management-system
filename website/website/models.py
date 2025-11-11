from . import db
from flask_login import UserMixin

class User(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(150), unique=True, nullable=False)
    username = db.Column(db.String(150), unique=True, nullable=False)
    password = db.Column(db.String(150), nullable=False)
    is_admin = db.Column(db.Boolean, default=False)

    # Global and universal settings
    global_domain = db.Column(db.String(150), default="example.local")
    global_timezone = db.Column(db.String(150), default="Etc/UTC")
    universal_username = db.Column(db.String(150))
    password_mode = db.Column(db.String(20), default="generate")
    universal_password_custom = db.Column(db.String(150), nullable=True)