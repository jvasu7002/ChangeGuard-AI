
def get_user(username):
    print("Fetching user:", username)
    if not username:
        return None
    return username



def update_user(username):
    # ChangeGuard test: checking change detection
    print("Updating user:", username)
    if not username:
        return None
    return username