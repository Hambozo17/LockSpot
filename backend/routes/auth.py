"""
Authentication Routes - Register, Login, Profile
Raw SQL Implementation
"""

from fastapi import APIRouter, HTTPException, Depends, status
from models.schemas import (
    UserRegisterRequest, UserLoginRequest, TokenResponse, 
    UserResponse, ErrorResponse
)
from services.auth_service import (
    hash_password, verify_password, create_access_token,
    get_current_user, get_token_expiration_seconds
)
from config.database import get_db_cursor, execute_query

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register_user(request: UserRegisterRequest):
    """
    Register a new user account
    
    - Creates user in database
    - Returns JWT token for immediate login
    """
    # Check if email already exists
    check_email_query = """
        SELECT UserID FROM User WHERE Email = %s
    """
    existing_user = execute_query(check_email_query, (request.email,), fetch_one=True)
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Check if phone already exists
    check_phone_query = """
        SELECT UserID FROM User WHERE Phone = %s
    """
    existing_phone = execute_query(check_phone_query, (request.phone,), fetch_one=True)
    
    if existing_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered"
        )
    
    # Hash password
    password_hash = hash_password(request.password)
    
    # Insert new user - RAW SQL
    insert_query = """
        INSERT INTO User (FirstName, LastName, Email, Phone, PasswordHash, UserType, IsVerified)
        VALUES (%s, %s, %s, %s, %s, 'Customer', FALSE)
    """
    
    with get_db_cursor(commit=True) as (cursor, conn):
        cursor.execute(insert_query, (
            request.first_name,
            request.last_name,
            request.email,
            request.phone,
            password_hash
        ))
        user_id = cursor.lastrowid
    
    # Create access token
    token_data = {
        "user_id": user_id,
        "email": request.email,
        "user_type": "Customer"
    }
    access_token = create_access_token(token_data)
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=get_token_expiration_seconds(),
        user=UserResponse(
            user_id=user_id,
            first_name=request.first_name,
            last_name=request.last_name,
            email=request.email,
            phone=request.phone,
            user_type="Customer",
            is_verified=False
        )
    )


@router.post("/login", response_model=TokenResponse)
async def login_user(request: UserLoginRequest):
    """
    Login with email and password
    
    - Validates credentials
    - Returns JWT token
    """
    # Get user by email - RAW SQL
    query = """
        SELECT UserID, FirstName, LastName, Email, Phone, 
               PasswordHash, UserType, IsVerified, CreatedAt
        FROM User 
        WHERE Email = %s
    """
    user = execute_query(query, (request.email,), fetch_one=True)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # Verify password
    if not verify_password(request.password, user["PasswordHash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # Create access token
    token_data = {
        "user_id": user["UserID"],
        "email": user["Email"],
        "user_type": user["UserType"]
    }
    access_token = create_access_token(token_data)
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=get_token_expiration_seconds(),
        user=UserResponse(
            user_id=user["UserID"],
            first_name=user["FirstName"],
            last_name=user["LastName"],
            email=user["Email"],
            phone=user["Phone"],
            user_type=user["UserType"],
            is_verified=user["IsVerified"],
            created_at=user["CreatedAt"]
        )
    )


@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(current_user: dict = Depends(get_current_user)):
    """
    Get current authenticated user's profile
    """
    query = """
        SELECT UserID, FirstName, LastName, Email, Phone, 
               UserType, IsVerified, CreatedAt
        FROM User 
        WHERE UserID = %s
    """
    user = execute_query(query, (current_user["user_id"],), fetch_one=True)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return UserResponse(
        user_id=user["UserID"],
        first_name=user["FirstName"],
        last_name=user["LastName"],
        email=user["Email"],
        phone=user["Phone"],
        user_type=user["UserType"],
        is_verified=user["IsVerified"],
        created_at=user["CreatedAt"]
    )


@router.put("/me", response_model=UserResponse)
async def update_user_profile(
    first_name: str = None,
    last_name: str = None,
    phone: str = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Update current user's profile
    """
    # Build dynamic update query
    updates = []
    params = []
    
    if first_name:
        updates.append("FirstName = %s")
        params.append(first_name)
    if last_name:
        updates.append("LastName = %s")
        params.append(last_name)
    if phone:
        updates.append("Phone = %s")
        params.append(phone)
    
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update"
        )
    
    params.append(current_user["user_id"])
    
    query = f"""
        UPDATE User 
        SET {', '.join(updates)}
        WHERE UserID = %s
    """
    
    execute_query(query, tuple(params), commit=True)
    
    # Return updated user
    return await get_current_user_profile(current_user)
