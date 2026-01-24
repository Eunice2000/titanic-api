# titanic-api: Flask

Implemented using [Flask][] microframework.

## Installation and launching

### Clone

Clone the repo:

``` bash
git clone https://github.com/PipeOpsHQ/titanic-api.git
cd titanic-api
```

### Install

Use [venv][] or any other ([Pipenv][], [Poetry][], etc) [environment management][] tool to install dependencies in the same folder.
Activate virtual environment and run:

``` bash
pip install -r requirements.txt
```

### Launch

This API was tested using postgres. In order to bring it up, the following commands are needed:

1) Start postgres locally with `docker run --net=host --name titanic-db -e POSTGRES_PASSWORD=password -e POSTGRES_USER=user -d postgres`
3) Run the sql file with the database definition `docker cp titanic.sql titanic-db:/`
4) Run the sql file with `docker exec -it --rm titanic-db psql -U user -d postgres -f titanic.sql`


After you have database server deployed and running, use environment variable `DATABASE_URL` to provide database connection string.

``` bash
DATABASE_URL=postgresql+psycopg2://user:password@127.0.0.1:5432/postgres python run.py
```

Go to <http://127.0.0.1:5000/> in your browser.

Test it by:
1) See the database is currently empty with: `http://127.0.0.1:5000/people`
2) Add a new user with `curl -H "Content-Type: application/json" -X POST localhost:5000/people -d'{"survived": 2,"passengerClass": 2,"name": "Mr. Owen Harris Braund","sex": "male","age": 22.0,"siblingsOrSpousesAboard": 4,"parentsOrChildrenAboard": 5,"fare": 7.25}`
3) Check out if the user was added with `http://127.0.0.1:5000/people`

[Flask]: http://flask.pocoo.org/
[venv]: https://docs.python.org/3/tutorial/venv.html
[Pipenv]: https://pipenv.pypa.io/en/latest/
[Poetry]: https://python-poetry.org/docs/
[environment management]: http://docs.python-guide.org/en/latest/dev/virtualenvs/
