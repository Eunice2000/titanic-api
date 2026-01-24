from flask import Flask
from .config import app_config
from .models import db
from .views.people import people_api as people


def create_app(env_name: str) -> Flask:
    """
    Initializes the application registers

    Parameters:
        env_name: the name of the environment to initialize the app with

    Returns:
        The initialized app instance
    """
    app = Flask(__name__)
    app.config.from_object(app_config[env_name])
    db.init_app(app)

    app.register_blueprint(people, url_prefix="/")

    @app.route('/', methods=['GET'])
    def index():
        """
        Root endpoint for populating root route

        Returns:
            Greeting message
        """
        return """
        Welcome to the Titanic API
        """

    return app
