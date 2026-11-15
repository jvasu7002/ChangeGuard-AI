from user import get_user


def login(username, password):
    user = get_user(username)
    return authenticate(user)


def authenticate(user):
    return user is not None