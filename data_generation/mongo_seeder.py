"""
RideSync - MongoDB Geospatial & Review Data Seeder
Generates 500k+ realistic TelemetryPings with GeoJSON coordinates and TripReviews.
"""

import os
import random
import uuid
from datetime import datetime, timedelta
from dotenv import load_dotenv
from pymongo import MongoClient
from faker import Faker
from tqdm import tqdm

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
MONGO_DB = os.getenv("MONGO_DB", "ridesync_db")

TOTAL_PINGS = 500000
TOTAL_REVIEWS = 50000

fake = Faker()

# Center coordinates (Hyderabad City Center: [Longitude, Latitude])
CENTER_LNG = 78.3820
CENTER_LAT = 17.4435

TAG_POOL = [
    "Clean Car", "Smooth Drive", "Polite Driver", "Great Music",
    "Fast Route", "Safe Driving", "AC Was Cold", "Late Arrival",
    "Rash Driving", "Unprofessional", "Navigation Issue", "Good Conversation"
]


def seed_mongodb():
    print(f"Connecting to MongoDB at {MONGO_URI}...")
    client = MongoClient(MONGO_URI)
    db = client[MONGO_DB]

    # Generate Telemetry Pings
    print(f"Seeding {TOTAL_PINGS} TelemetryPings with GeoJSON 2dsphere points...")
    pings_collection = db["TelemetryPings"]
    
    batch_size = 10000
    pings_batch = []
    
    now = datetime.utcnow()
    
    for i in tqdm(range(TOTAL_PINGS), desc="Telemetry Pings"):
        # Spread points within ~15km radius of city center
        lng_offset = random.uniform(-0.15, 0.15)
        lat_offset = random.uniform(-0.15, 0.15)
        
        # Ping timestamps within the last 1.5 hours (within 2-hr TTL window)
        ping_time = now - timedelta(seconds=random.randint(0, 5400))
        
        doc = {
            "ping_id": str(uuid.uuid4()),
            "vehicle_id": str(uuid.uuid4()),
            "is_available": random.random() > 0.3,
            "speed_kmh": round(random.uniform(0.0, 95.0), 1),
            "heading_degrees": round(random.uniform(0.0, 360.0), 1),
            "location": {
                "type": "Point",
                "coordinates": [round(CENTER_LNG + lng_offset, 6), round(CENTER_LAT + lat_offset, 6)]
            },
            "created_at": ping_time
        }
        pings_batch.append(doc)

        if len(pings_batch) >= batch_size:
            pings_collection.insert_many(pings_batch, ordered=False)
            pings_batch = []

    if pings_batch:
        pings_collection.insert_many(pings_batch, ordered=False)

    # Generate Trip Reviews
    print(f"Seeding {TOTAL_REVIEWS} TripReviews...")
    reviews_collection = db["TripReviews"]
    reviews_batch = []

    for _ in tqdm(range(TOTAL_REVIEWS), desc="Trip Reviews"):
        rating = random.choices([5, 4, 3, 2, 1], weights=[50, 25, 12, 8, 5])[0]
        num_tags = random.randint(1, 4)
        tags = random.sample(TAG_POOL, num_tags)
        
        doc = {
            "review_id": str(uuid.uuid4()),
            "trip_id": str(uuid.uuid4()),
            "rider_id": str(uuid.uuid4()),
            "vehicle_id": str(uuid.uuid4()),
            "rating": int(rating),
            "feedback_tags": tags,
            "comment": fake.sentence() if random.random() > 0.4 else None,
            "created_at": fake.date_time_between(start_date="-60d", end_date="now")
        }
        reviews_batch.append(doc)

        if len(reviews_batch) >= batch_size:
            reviews_collection.insert_many(reviews_batch, ordered=False)
            reviews_batch = []

    if reviews_batch:
        reviews_collection.insert_many(reviews_batch, ordered=False)

    print("MongoDB seeding completed successfully!")


if __name__ == "__main__":
    seed_mongodb()
