#!/bin/bash

#begin of setup_task_manager.sh
# This script is used to set up the "Task Manager with User Authentication" project.
# It creates the necessary directory structure, generates the main application file,
# template files, requirements file, configuration files, and also provides a self-extracting
# script part along with a script for managing Docker containers.

# Get today's date in the format of YYYY-MM-DD
# The 'date' command is used to obtain the current date, and the output is formatted
# as YYYY-MM-DD and assigned to the variable 'today'.
today=$(date +"%Y-%m-%d")

# Archive content starts here
# self extraction script for project "Task Manager with User Authentication"
# Filename: setup_task_manager.sh
# Author: Shouwei Lin
# Email: shwlin@163.com
# Date: $today

# Create the main 'task_manager_bundle' directory if it doesn't exist.
# The '-p' option ensures that the directory and any necessary parent directories
# are created without raising an error if they don't already exist.
# Then, print a message indicating whether the directory was created or already existed.
if mkdir -p task_manager_bundle; then
    echo "task_manager_bundle directory created successfully or already exists."
else
    echo "Failed to create task_manager_bundle directory."
    exit 1
fi

# Create the 'data' subdirectory within 'task_manager_bundle'.
# Again, using the '-p' option and printing a status message.
if mkdir -p task_manager_bundle/data; then
    echo "task_manager_bundle/data directory created successfully or already exists."
else
    echo "Failed to create task_manager_bundle/data directory."
    exit 1
fi

# Create the 'log' subdirectory within 'task_manager_bundle'.
# With the same approach of using '-p' option and printing a message.
if mkdir -p task_manager_bundle/log; then
    echo "task_manager_bundle/log directory created successfully or already exists."
else
    echo "Failed to create task_manager_bundle/log directory."
    exit 1
fi


# Create the 'templates' subdirectory within 'task_manager_bundle'.
# With the same approach of using '-p' option and printing a message.
if mkdir -p task_manager_bundle/templates; then
    echo "task_manager_bundle/templates directory created successfully or already exists."
else
    echo "Failed to create task_manager_bundle/templates directory."
    exit 1
fi

# Create the main application file with header
cat << 'EOF' > task_manager_bundle/app.py
# Filename: app.py
# Author: Shouwei Lin
# Email: shwlin@163.com
# Date: $today

import json
import os
import hashlib
import logging
from flask import Flask, render_template, request, redirect, url_for, flash, session
from datetime import datetime, timedelta
from dotenv import load_dotenv

app = Flask(__name__)

# Load environment variables from the.env file if it exists.
# The loaded variables can then be accessed in the application code.
load_dotenv()
app.secret_key = os.getenv('SECRET_KEY')

# Configure logging for the application.
# Set the log file path to 'app.log' within the 'log' subdirectory of the application.
# Set the logging level to INFO, which means it will record informational messages and above.
script_dir = os.path.dirname(os.path.abspath(__file__))
log_file = os.path.join(script_dir, 'log', 'app.log')
logging.basicConfig(filename=log_file, level=logging.INFO)

# Global variables defining the file paths for user credentials and task data.
# These paths are used throughout the application to read and write relevant data.
user_credentials_file = os.path.join(script_dir, 'data', 'users.json')
task_data_file = os.path.join(script_dir, 'data', 'tasks.csv')

# Function to hash a password.
# It takes a password as a string, encodes it to bytes, and then computes its SHA256 hash value.
# The hashed password is returned for storage and comparison purposes.
def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()


# Function to check if the user's session token has timed out.
# It checks if the 'login_time' is stored in the session.
# If it is, it calculates the time difference between the current time and the login time.
# If the time difference is greater than 10 minutes, it returns True indicating the session has timed out; otherwise, it returns False.
def has_token_timed_out():
    if 'login_time' in session:
        login_time = datetime.fromisoformat(session['login_time'])
        current_time = datetime.now()
        time_difference = current_time - login_time
        return time_difference > timedelta(minutes=10)
    return False


# Decorator function to require user login.
# It checks if the user is logged in and if their session hasn't timed out.
# If not, it redirects the user to the login page with an appropriate error message.
def login_required(func):
    def wrapper(*args, **kwargs):
        if 'username' not in session or has_token_timed_out():
            flash('You must be logged in. Your session has timed out. Please log in again.', 'error')
            return redirect(url_for('login'))
        return func(*args, **kwargs)
    wrapper.__name__ = func.__name__  # Preserve the original function name
    return wrapper


# Function to read user credentials file
def read_user_credentials():
    users = {}
    if os.path.exists(user_credentials_file):
        try:
            with open(user_credentials_file, 'r') as f:
                users = json.load(f)
        except FileNotFoundError:
            logging.error(f"User credentials file {user_credentials_file} not found.")
            return {}
        except json.JSONDecodeError as e:
            logging.error(f"Error decoding JSON in user credentials file: {e}")
            return {}
    return users


# Function to read task data file
def read_task_data():
    tasks = []
    if os.path.exists(task_data_file):
        try:
            with open(task_data_file, 'r', newline='') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    tasks.append(row)
        except FileNotFoundError:
            logging.error(f"Task data file {task_data_file} not found.")
            return []
        except csv.Error as e:
            logging.error(f"Error reading CSV in task data file: {e}")
            return []
    return tasks


@app.route('/')
@login_required
def home():
    """
    This function is responsible for rendering the home page of the task manager application.
    It provides a menu of options for the logged-in user to perform various task management operations such as adding tasks,
    viewing tasks, marking tasks as completed, and deleting tasks.

    :return: Renders the home.html template with the available menu options and a link to return home.
    """
    logging.debug("Entering home route")
    username = session['username']

    # Get the task data for the current user
    tasks = read_task_data()
    user_tasks = [task for task in tasks if task['username'] == username]

    return render_template('home.html', choices=[
        "1. Add Task",
        "2. View Tasks",
        "3. Mark Task as Completed",
        "4. Delete Task",
        "5. Logout"
    ], home_url=url_for('home'), user_tasks=user_tasks)


# User registration function.
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        users = read_user_credentials()

        if username in users:
            logging.error("Username already exists")
            flash('Username already exists. Please choose another one.', 'error')
            return redirect(url_for('register'))

        hashed_password = hash_password(password)
        users[username] = {'password_hash': hashed_password}

        # Write the updated user dictionary back to the user credentials file.
        try:
            with open(user_credentials_file, 'w') as f:
                json.dump(users, f)
            logging.info("User registered successfully")
            flash('Registration successful. You can now login.', 'success')
            return redirect(url_for('login'))
        except json.JSONDecodeError as e:
            logging.error(f"Error encoding JSON in user credentials file: {e}")
            flash('Error saving user credentials. Please try again.', 'error')
            return redirect(url_for('register'))
    return render_template('register.html')


# User login function.
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        users = read_user_credentials()

        if username not in users or hash_password(password)!= users[username]['password_hash']:
            logging.error("Invalid username or password")
            flash('Invalid username or password. Please try again.', 'error')
            return redirect(url_for('login'))

        session['username'] = username
        session['login_time'] = datetime.now().isoformat()
        logging.info(f"User {username} logged in successfully")
        flash('Login successful.', 'success')
        return redirect(url_for('home'))
    return render_template('login.html')


# Function to generate a task ID.
# If the task data file doesn't  exist, it returns 1 as the initial task ID.
# If it exists, it reads the existing tasks, extracts the task IDs, and returns the maximum ID plus 1.
def generate_task_id():
    if not os.path.exists(task_data_file):
        return 1
    task_ids = []
    with open(task_data_file, "r", newline='') as f:
        reader = csv.reader(f)
        next(reader)  # 跳过标题行
        for row in reader:
            task_ids.append(int(row[0]))  # 假设任务ID在第一列
    return max(task_ids) + 1 if task_ids else 1


# Function to add a task.
@app.route('/add_task', methods=['GET', 'POST'], endpoint='add_task')
@login_required
def add_task():
    if request.method == 'POST':
        task_description = request.form['description']
        task_due_date = request.form['due_date']

        task_id = generate_task_id()

        new_task = {
            'id': task_id,
            'description': task_description,
            'due_date': task_due_date,
            'completed': False,
            'username': session['username']
        }

        tasks = read_task_data()

        if session['username'] not in tasks:
            tasks[session['username']] = []

        tasks[session['username']].append(new_task)

        try:
            with open(task_data_file, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['id', 'description', 'due_date', 'completed', 'username'])
                writer.writeheader()
                for task in tasks:
                    writer.writerow(task)
            logging.info(f"Task added: {new_task}")
            flash('Task added successfully!', 'success')
            return redirect(url_for('home'))
        except csv.Error as e:
            logging.error(f"Error writing CSV in task data_file: {e}")
            flash('Error saving task data. Please try again.', 'error')
            return redirect(url_for('add_task'))
    return render_template('add_task.html')


# Function to display tasks.
@app.route('/task_manager', endpoint='task_manager')
@login_required
def task_manager():
    tasks = read_task_data()
    user_tasks = [task for task in tasks if task['username'] == session['username']]
    return render_template('task_manager.html', tasks=user_tasks)


# Function to mark a task as completed.
@app.route('/complete_task/<int:task_id>', methods=['POST'], endpoint='complete_task')
@login_required
def complete_task(task_id):
    tasks = read_task_data()
    user_tasks = [task for task in tasks if task['username'] == session['username']]
    for task in user_tasks:
        if task['id'] == task_id:
            task['completed'] = True
            break
    try:
      with open(task_data_file, 'w', newline='') as f:
          writer = csv.DictWriter(f, fieldnames=['id', 'description', 'due_date', 'completed', 'username'])
          writer.writeheader()
          for task in tasks:
              writer.writerow(task)
          logging.info(f"Task {task_id} marked as completed")
          flash('Task marked as completed!', 'success')
          return redirect(url_for('task_manager'))
    except csv.Error as e:
        logging.error(f"Error writing CSV in task data_file: {e}")
        flash('Error decoding task data. Please check the file.', 'error')
        return redirect(url_for('task_manager'))


# Function to delete a task.
@app.route('/delete_task/<int:task_id>', methods=['POST'], endpoint='delete_task')
@login_required
def delete_task(task_id):
    tasks = read_task_data()
    user_tasks = [task for task in tasks if task['username'] == session['username']]
    tasks[session['username']] = [task for task in user_tasks if task['id']!= task_id]
    try:
        with open(task_data_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=['id', 'description', 'due_date', 'completed', 'username'])
            writer.writeheader()
            for task in tasks:
                writer.writerow(task)
            logging.info(f"Task {task_id} deleted")
            flash('Task deleted successfully!', 'success')
            return redirect(url_for('task_manager'))
    except csv.Error as e:
        logging.error(f"Error writing CSV in task data_file: e")
        flash('Error decoding task data. Please check the file.', 'error')
        return redirect(url_for('task_manager'))


# User logout function.
@app.route('/logout')
@login_required
def logout():
    session.pop('username', None)
    session.pop('login_time', None)
    logging.info(f"User {session.get('username')} logged out")
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5002)
EOF


cat << 'EOF' > task_manager_bundle/data/users.json
{
    "user1": {
        "password_hash": "hashed_password_value_for_user1"
    },
    "user2": {
        "password_hash": "hashed_password_value_for_user2"
    }
}
EOF

cat << 'EOF' > task_manager_bundle/data/tasks.csv
id,description,due_date,completed,username
1,"Buy groceries","2024-11-10",false,"user1"
2,"Finish report","2024-11-15",false,"user1"
EOF

cat << 'EOF' > task_manager_bundle/log/app.log
2024-11-08 14:30:00 INFO User user1 logged in successfully
EOF

# Create template files
cat << 'EOF' > task_manager_bundle/templates/home.html
<!DOCTYPE html>
<html>

<head>
  <title>Task Manager Home</title>
</head>

<body>
  {% if username %}
  <h1>Welcome, {{ username }}!</h1>
  {% else %}
  <h1>Welcome to the Task Manager!</h1>
  {% endif %}
  <p>This is your task management dashboard. From here, you can access all your tasks and manage them efficiently.</p>
  <ul>
    <li><a href="{{ url_for('add_task') }}">Add Task</a></li>
    <li><a href="{{ url_for('task_manager') }}">View Tasks</a></li>
    {% if username %}
    <li><a href="{{ url_for('logout') }}">Logout</a></li>
    {% else %}
    <li><a href="{{ url_for('login') }}">Login</a></li>
    <li><a href="{{ url_for('register') }}">Register</a></li>
    {% endif %}
  </ul>
</body>

</html>
EOF

# Create the 'login.html' template file within the 'templates' directory of 'task_manager_bundle'.
# This file provides the user interface for logging in.
cat << 'EOF' > task_manager_bundle/templates/login.html
<!DOCTYPE html>
<html>
<head>
    <title>Login</title>
</head>
<body>
    <h1>Login</h1>
    <form method="POST">
        Username: <input type="text" name="username" required>
        Password: <input type="password" name="password" required>
        <button type="submit">Login</button>
    </form>
    <p>Don't have an account? <a href="{{ url_for('register') }}">Register here</a></p>
</body>
</html>
EOF

# Create the 'register.html' template file within the 'templates' directory of 'task_manager_bundle'.
# This file provides the user interface for registering a new account.
cat << 'EOF' > task_manager_bundle/templates/register.html
<!DOCTYPE html>
<html>
<head>
    <title>Register</title>
</head>
<body>
    <h1>Register</h1>
    <form method="POST">
        <label for="username">Username:</label>
        <input type="text" id="username" name="username" required>
        <label for="password">Password:</label>
        <input type="password" id="password" name="password" required>
        <button type="submit">Register</button>
    </form>
    {% if error %}
        <p>{{ error }}</p>
    {% endif %}
    <a href="{{ url_for('login') }}">Already have an account? Login here</a>
</body>
</html>
EOF

# Create the 'task_manager.html' template file within the 'templates' directory of 'task_manager_bundle'.
# This file provides the user interface for viewing and managing tasks.
cat << 'EOF' > task_manager_bundle/templates/task_manager.html
<!DOCTYPE html>
<html>
<head>
    <title>Task Manager</title>
</head>
<body>
    <h1>Your Tasks</h1>
    <a href="{{ url_for('add_task') }}">Add Task</a>
    <ul>
        {% for task in tasks %}
            <li>
                {{ task.description }} - Due: {{ task.due_date }}
                {% if not task.completed %}
                    <form action="{{ url_for('complete_task', task_id=task.id) }}" method="POST" style="display:inline;">
                        <button type="submit">Complete</button>
                    </form>
                    <form action="{{ url_for('delete_task', task_id=task.id) }}" method="POST" style="display:inline;">
                        <button type="submit">Delete</button>
                    </form>
                {% else %}
                    <strong>Completed</strong>
                {% endif %}
            </li>
        {% endfor %}
    </ul>
    <a href="{{ url_for('logout') }}">Logout</a>
</body>
</html>
EOF

# Create the 'add_task.html' template file within the 'templates' directory of 'task_manager_bundle'.
# This file provides the user interface for adding new tasks.
cat << 'EOF' > task_manager_bundle/templates/add_task.html
<!DOCTYPE html>
<html>
<head>
    <title>Add Task</title>
</head>
<body>
    <h1>Add Task</h1>
    <form method="POST">
        <label for="description">Task Description:</label>
        <input type="text" id="description" name="description" required>
        <label for="due_date">Due Date:</label>
        <input type="date" id="due_date" name="due_date" required>
        <button type="submit">Add Task</button>
    </form>
    {% if error %}
        <p>{{ error }}</p>
    {% endif %}
    <a href="{{ url_for('home') }}">Return to Home</a>
</body>
</html>
EOF

# Create the 'complete_task.html' template file within the 'templates' directory of 'task_manager_bundle'.
# This file could be used to show a confirmation message after marking a task as completed.
# (Optional, depending on the desired user experience)
cat << 'EOF' > task_manager_bundle/templates/complete_task.html
<!DOCTYPE html>
<html>
<head>
    <title>Task Completed</title>
</head>
<body>
    <h1>Task Marked as Completed</h1>
    <p>The task has been successfully marked as completed.</p>
    <a href="{{ url_for('task_manager') }}">Return to Task Manager</a>
</body>
</html>
EOF

# Create the 'delete_task.html' template file within the 'templates' directory of 'task_manager_bundle'.
# This file could be used to show a confirmation message after deleting a task.
# (Optional, depending on the desired user experience)
cat << 'EOF' > task_manager_bundle/templates/delete_task.html
<!DOCTYPE html>
<html>
<head>
    <title>Task Deleted</title>
</head>
<body>
    <h1>Task Deleted</h1>
    <p>The task has been successfully deleted.</p>
    <a href="{{ url_for('task_manager') }}">Return to Task Manager</a>
</body>
</html>
EOF

# Create the requirements.txt file for the project
cat << 'EOF' > task_manager_bundle/requirements.txt
Flask==2.0.1
flask_babel==4.0.0
python-dotenv==1.0.1
Werkzeug==2.0.3
EOF

# Create the.env file for storing environment variables
cat << 'EOF' > task_manager_bundle/.env
SECRET_KEY=my_secret_key_321
EOF

# Create README.md
cat << 'EOF' > task_manager_bundle/README.md
# Task Manager with User Authentication README

## Screenshots
### Home Page
![Screenshot of the Expense Tracker Interface](./screenshots/home.jpg)

### Rigister page
![Screenshot of the Expense Tracker Interface](./screenshots/register.jpg)

### Login page
![Screenshot of the Expense Tracker Interface](./screenshots/login.jpg)

### Set Monthly Budget page
![Screenshot of the Expense Tracker Interface](./screenshots/task_manager.jpg)


## Overview
This project is a task management application that enables users to manage their tasks securely with user authentication. It's built using Flask, a well-known Python web framework.

## Features
- **User Authentication**:
    - Users can create accounts and log in using their usernames and passwords.
    - Passwords are hashed for storage, enhancing security.
- **Task Management**:
    - Add new tasks by providing a description and due date.
    - View a list of tasks on the task manager page, including details like description and due date.
    - Mark tasks as completed or delete them as needed.
- **Session Management**:
    - The application tracks user sessions and enforces a timeout. If a session times out, users must log in again.

## Installation
1. **Clone the Repository**
    - Use the command: `git clone [repository-url]` (replace `[repository-url]` with the actual repository URL).
2. **Set Up Virtual Environment (Optional but Recommended)**
    - Navigate to the project directory (where `task_manager_bundle` is located).
    - For Linux/macOS:
        - Create a virtual environment: `python -m venv venv`
        - Activate it: `source venv/bin/activate`
    - For Windows:
        - Create a virtual environment: `python -m venv venv`
        - Activate it: `venv\Scripts\activate`
3. **Install Dependencies**
    - Ensure `pip` is installed.
    - Install required Python packages from `requirements.txt` using: `pip install -r requirements.txt`
4. **Set Up Environment Variables**
    - Create a `.env` file in the project root directory (same level as `task_manager_bundle`).
    - Add: `SECRET_KEY=your_random_secret_key` (replace `your_random_secret_key` with a real, randomly generated secret key).

## Usage
1. **Starting the Application**
    - Navigate to the project directory.
    - If using a virtual environment, activate it.
    - Run: `python task_manager_bundle/app.py`. The application runs on `http://127.0.0.1:5002/` (by default).
2. **Registering and Logging In**
    - Open your web browser and go to the application URL (usually `http://127.0.0.1:5002/`).
    - New users can click "Register" and fill out the form with a username and password.
    - After registering, log in using your username and password on the login page.
3. **Managing Tasks**
    - Once logged in, you'll be redirected to the task manager page.
    - To add a new task, click "Add Task" and fill out the task description and due date fields.
    - The task manager page shows a list of your tasks. For uncompleted tasks, you can click "Complete" to mark it as completed or "Delete" to delete it.

## File Structure
### task_manager_bundle
- **app.py**: Contains the Flask application logic, defining routes for user registration, login, task management operations, etc. Also includes functions for password hashing, session management, and handling user and task data.
- **data**:
    - **users.json**: Stores user credentials (username and hashed password) in JSON format.
    - **tasks.csv**: Stores task information for each user. Some code parts might handle it as if it were JSON, which could be optimized for consistency.
- **log**:
    - **app.log**: Records events and errors during application operation. Logging level is set to INFO.
- **screenshots** (Optional): Can store screenshots related to the application for documentation or testing. For example, you can take screenshots of the login page, registration page, task manager page with different task states (e.g., tasks pending, tasks completed), and the add task page. These screenshots can be added to the `screenshots` directory within the `task_manager_bundle` folder.
- **templates**:
    - **add_task.html**: Provides the user interface for adding new tasks, with a form for description and due date and a submit button.
    - **login.html**: The login page template with a form for username and password and a login button. Also has a link to the registration page for new users.
    - **register.html**: The registration page template with a form for username and password and a register button.
    - **task_manager.html**: The task manager page template that shows a list of tasks. For uncompleted tasks, it has buttons to mark as completed and delete. Also has links to add a new task and log out.

### Project Root Directory (Same Level as task_manager_bundle)
- **requirements.txt**: Lists the required Python packages and their versions for the project.
- **.env**: Stores environment variables like the `SECRET_KEY` used by the Flask application for security.
- **Dockerfile**: Used to build a Docker image for the application if containerization is desired.
- **manage.sh**: A script to manage Docker containers related to the application, such as building, starting, stopping, and removing containers.

## Adding Screenshots
To add screenshots to the project for better documentation or illustration purposes:
1. Navigate to the relevant page in the application (e.g., login page, task manager page) in your web browser.
2. Use the screenshot functionality of your operating system or a dedicated screenshot tool (e.g., Snipping Tool on Windows, Grab on macOS).
3. Save the screenshot with a meaningful name (e.g., `login_page_screenshot.png`, `task_manager_page_with_tasks.png`) in a location of your choice.
4. Move or copy the saved screenshot to the `screenshots` directory within the `task_manager_bundle` folder.

## Contributors
Shouwei Lin(shwlin@163.com, jacklin5168@gmail.com)

## License
This project is licensed under the MIT license.
EOF

# Create the Dockerfile for containerizing the application
cat << 'EOF' > task_manager_bundle/Dockerfile
# Use an official Python runtime as a base image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code
COPY . .

# Expose the new port
EXPOSE 5002

# Mount the Docker volume for data and log
VOLUME ["/app/data", "/app/log"]

# Define the command to run the application
CMD ["python", "app.py"]
EOF

# Create the manage.sh script for managing Docker containers related to the application
cat << 'EOF' > task_manager_bundle/manage.sh
#!/bin/bash

function build_image() {
    echo "Building the Docker container..."
    docker build -t task_manager .
}

function debug_container() {
    echo "Starting the Docker container in debug mode..."
    docker run -p 5002:5002 --name task_manager_container -v $(pwd)/data:/app/data -v $(pwd)/log:/app/log task_manager
}

function start_container() {
    echo "Starting the Docker container..."
    docker run -d -p 5002:5002 --name task_manager_container -v $(pwd)/data:/app/data -v $(pwd)/log:/app/log task_manager
}

function stop_container() {
    echo "Stopping the Docker container..."
    docker stop task_manager_container
}

function check_status() {
    echo "Checking the status of the Docker container..."
    docker ps -a | grep task_manager_container
}

function remove_container() {
    echo "Removing the Docker container..."
    docker rm task_manager_container
}

function clean_up() {
    echo "Cleaning up Docker-related resources..."
    stop_container
    remove_container
    docker image prune -a -f
}

case "$1" in
    "build")
        build_image
        ;;
    "debug")
        debug_container
        ;;
    "start")
        start_container
        ;;
    "stop")
        stop_container
        ;;
    "status")
        check_status
        ;;
    "remove")
        remove_container
        ;;
    "clean")
        clean_up
        ;;
    *)
        echo "Usage: $0 {build|debug|start|stop|remove|clean}"
        exit 1
esac
EOF

# Self-extracting script
ARCHIVE=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0)
tail -n+$ARCHIVE $0 | tar -xz

pwd
ls -lhrt
ls -lhrt task_manager_bundle/*

# Clean up any previous installation
if [ -d "task_manager/data" ]; then
    mv task_manager/data task_manager_bundle
    rm -rf task_manager
elif [ -d "task_manager" ]; then
    rm -rf task_manager
fi

# Move extracted files to the final location
mv task_manager_bundle task_manager

# Copy screenshots to the final location
if [ -d "screenshots" ]; then
    cp -rf screenshots task_manager/screenshots
fi

# Make manage.sh executable
chmod +x task_manager/manage.sh

pwd
ls -lhrt
ls -lhrt task_manager/*
#cd task_manager

# Provide instructions to the user
echo "Files extracted to 'task_manager'."
echo "Navigate to 'task_manager' and use './manage.sh {build|debug|start|stop|clean|status}' to manage the service."

exit 0

__ARCHIVE_BELOW__