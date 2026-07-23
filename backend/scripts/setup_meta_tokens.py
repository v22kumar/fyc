import http.server
import socketserver
import urllib.parse
import webbrowser
import requests
import sys

# The credentials provided by the user
IG_APP_ID = "909285875002274"
IG_APP_SECRET = "72403e3ff19da21956bb3de60f5f551e"

# We use localhost to easily catch the redirect
REDIRECT_URI = "http://localhost:8080/auth"
PORT = 8080

authorization_code = None

class OAuthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        global authorization_code
        parsed_path = urllib.parse.urlparse(self.path)
        
        if parsed_path.path == '/auth':
            query = urllib.parse.parse_qs(parsed_path.query)
            
            if 'code' in query:
                authorization_code = query['code'][0]
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b"<h1>Success!</h1><p>Authorization code received. You can close this window and return to your terminal.</p>")
                
                # Stop the server after receiving the code
                def kill_server():
                    self.server.shutdown()
                import threading
                threading.Thread(target=kill_server).start()
            else:
                self.send_response(400)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b"<h1>Error</h1><p>No authorization code found in URL.</p>")
        else:
            self.send_response(404)
            self.end_headers()

def generate_tokens():
    print("=" * 60)
    print("Meta API OAuth Setup for Instagram & Threads")
    print("=" * 60)
    
    # Instagram permissions (Basic Display / Graph API)
    permissions = "instagram_basic,instagram_manage_comments,pages_show_list,pages_read_engagement"
    
    auth_url = (
        f"https://www.facebook.com/v19.0/dialog/oauth?"
        f"client_id={IG_APP_ID}&"
        f"redirect_uri={REDIRECT_URI}&"
        f"scope={permissions}"
    )
    
    print(f"\n1. Opening browser to authorize your Facebook account...")
    print(f"If the browser doesn't open automatically, click this link:\n{auth_url}\n")
    
    try:
        webbrowser.open(auth_url)
    except:
        pass
        
    print("2. Waiting for your authorization (listening on http://localhost:8080)...")
    
    with socketserver.TCPServer(("", PORT), OAuthHandler) as httpd:
        httpd.serve_forever()
        
    if not authorization_code:
        print("\n[ERROR] Failed to get authorization code. Exiting.")
        sys.exit(1)
        
    print(f"\n[SUCCESS] Authorization code caught: {authorization_code[:10]}...")
    print("\n3. Exchanging code for a Short-Lived Access Token...")
    
    token_url = f"https://graph.facebook.com/v19.0/oauth/access_token"
    params = {
        "client_id": IG_APP_ID,
        "redirect_uri": REDIRECT_URI,
        "client_secret": IG_APP_SECRET,
        "code": authorization_code
    }
    
    res = requests.get(token_url, params=params)
    if res.status_code != 200:
        print(f"[ERROR] Failed to get short-lived token: {res.text}")
        sys.exit(1)
        
    short_lived_token = res.json().get("access_token")
    print("[SUCCESS] Short-lived token acquired!")
    
    print("\n4. Exchanging short-lived token for a Long-Lived Access Token...")
    long_lived_url = f"https://graph.facebook.com/v19.0/oauth/access_token"
    params = {
        "grant_type": "fb_exchange_token",
        "client_id": IG_APP_ID,
        "client_secret": IG_APP_SECRET,
        "fb_exchange_token": short_lived_token
    }
    
    res = requests.get(long_lived_url, params=params)
    if res.status_code != 200:
        print(f"[ERROR] Failed to get long-lived token: {res.text}")
        sys.exit(1)
        
    long_lived_token = res.json().get("access_token")
    
    print("\n" + "=" * 60)
    print("🎉 SUCCESS! YOU HAVE YOUR LONG-LIVED ACCESS TOKEN 🎉")
    print("=" * 60)
    print("\nPlease copy this token and provide it back in the chat:")
    print("-" * 60)
    print(long_lived_token)
    print("-" * 60)
    print("\nNext steps: We will use this token in the backend to sync your Instagram feeds!")

if __name__ == "__main__":
    generate_tokens()
