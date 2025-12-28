"""
LockSpot Backend API - Main Entry Point
Using FastAPI with Raw SQL (No ORM)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Import routes
from routes import auth, locations, lockers, bookings, payments, reviews, discounts

# Create FastAPI app
app = FastAPI(
    title="LockSpot API",
    description="Smart Locker Booking System - Backend API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins + ["*"],  # Allow all for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(locations.router, prefix="/locations", tags=["Locations"])
app.include_router(lockers.router, prefix="/lockers", tags=["Lockers"])
app.include_router(bookings.router, prefix="/bookings", tags=["Bookings"])
app.include_router(payments.router, prefix="/payments", tags=["Payments"])
app.include_router(reviews.router, prefix="/reviews", tags=["Reviews"])
app.include_router(discounts.router, prefix="/discounts", tags=["Discounts"])


@app.get("/", tags=["Health"])
async def root():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "LockSpot API",
        "version": "1.0.0",
        "documentation": "/docs"
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """Detailed health check"""
    from config.database import get_db_connection
    
    db_status = "disconnected"
    try:
        conn = get_db_connection()
        if conn and conn.is_connected():
            db_status = "connected"
            conn.close()
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return {
        "status": "healthy",
        "database": db_status,
        "environment": "development" if os.getenv("DEBUG", "False").lower() == "true" else "production"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
