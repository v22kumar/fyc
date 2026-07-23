import asyncio
import httpx
from app.core.database import SessionLocal
from app.models.tenant import Organization

async def test_posting():
    db = SessionLocal()
    org = db.query(Organization).first()
    
    if not org:
        print("Error: No Organization found in DB.")
        return
        
    print("--- Testing Instagram Posting ---")
    if not org.instagram_access_token or not org.instagram_account_id:
        print("Error: Instagram tokens not found in DB. Did you do the OAuth login?")
    else:
        ig_caption = "Hello from FYC Connect API! 🚀 Testing Instagram integration."
        # using a placeholder image for testing IG posting
        ig_img = "https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0?w=800"
        
        async with httpx.AsyncClient() as client:
            try:
                print("1. Creating IG Container...")
                r1 = await client.post(
                    f"https://graph.facebook.com/v19.0/{org.instagram_account_id}/media",
                    params={"image_url": ig_img, "caption": ig_caption, "access_token": org.instagram_access_token},
                )
                r1.raise_for_status()
                container_id = r1.json()["id"]
                
                print("2. Publishing IG Container...")
                r2 = await client.post(
                    f"https://graph.facebook.com/v19.0/{org.instagram_account_id}/media_publish",
                    params={"creation_id": container_id, "access_token": org.instagram_access_token},
                )
                r2.raise_for_status()
                print(f"SUCCESS! Instagram Post ID: {r2.json()['id']}")
            except Exception as e:
                print(f"Failed to post to Instagram: {e}")

    print("\n--- Testing Threads Posting ---")
    if not org.threads_access_token or not org.threads_account_id:
        print("Error: Threads tokens not found in DB. Did you do the OAuth login?")
    else:
        th_text = "Hello Threads! 🧵 This is a test post directly from the FYC Connect backend."
        
        async with httpx.AsyncClient() as client:
            try:
                print("1. Creating Threads Container...")
                tr1 = await client.post(
                    f"https://graph.threads.net/v1.0/{org.threads_account_id}/threads",
                    data={"media_type": "TEXT", "text": th_text, "access_token": org.threads_access_token},
                )
                tr1.raise_for_status()
                t_container_id = tr1.json()["id"]
                
                print("2. Publishing Threads Container...")
                tr2 = await client.post(
                    f"https://graph.threads.net/v1.0/{org.threads_account_id}/threads_publish",
                    data={"creation_id": t_container_id, "access_token": org.threads_access_token},
                )
                tr2.raise_for_status()
                print(f"SUCCESS! Threads Post ID: {tr2.json()['id']}")
            except Exception as e:
                print(f"Failed to post to Threads: {e}")

if __name__ == "__main__":
    asyncio.run(test_posting())
