"""
JWT Authentication for Django REST Framework
"""

import jwt
from datetime import datetime, timedelta
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from lockers.models import User


class JWTAuthentication(BaseAuthentication):
    """JWT Token Authentication"""
    
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return None
        
        try:
            prefix, token = auth_header.split(' ')
            if prefix.lower() != 'bearer':
                return None
        except ValueError:
            return None
        
        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET,
                algorithms=[settings.JWT_ALGORITHM]
            )
        except jwt.ExpiredSignatureError:
            raise AuthenticationFailed('Token has expired')
        except jwt.InvalidTokenError:
            raise AuthenticationFailed('Invalid token')
        
        try:
            user = User.objects.get(id=payload.get('user_id'))
        except User.DoesNotExist:
            raise AuthenticationFailed('User not found')
        
        return (user, token)


def create_access_token(user):
    """Generate JWT token for user"""
    expiration = datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRATION_HOURS)
    
    payload = {
        'user_id': user.id,
        'email': user.email,
        'user_type': user.user_type,
        'exp': expiration,
        'iat': datetime.utcnow()
    }
    
    token = jwt.encode(
        payload,
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM
    )
    
    return token


def get_token_expiration_seconds():
    """Get token expiration in seconds"""
    return settings.JWT_EXPIRATION_HOURS * 3600
